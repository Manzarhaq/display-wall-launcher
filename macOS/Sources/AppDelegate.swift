import AppKit
import WebKit

final class AppDelegate: NSObject, NSApplicationDelegate, WKNavigationDelegate, NSWindowDelegate {
    private let settings = UserDefaults(suiteName: "io.github.displaywalllauncher")!
    private var setup: SetupWindow!
    private var wall: WallWindow?
    private var web: WKWebView?
    private var previousOptions: NSApplication.PresentationOptions?
    private var keyMonitor: Any?
    private var loadTimer: Timer?
    private var presenting = false
    private var smokeFinished = false
    private var smokeOriginalOptions: NSApplication.PresentationOptions = []
    private let smoke = ProcessInfo.processInfo.arguments.contains("--smoke-test")
    private let smokeFailure = ProcessInfo.processInfo.arguments.contains("--smoke-failure")
    private let smokeBlank = ProcessInfo.processInfo.arguments.contains("--smoke-blank")
    private var testing: Bool { smoke || smokeFailure || smokeBlank }

    func applicationDidFinishLaunching(_ notification: Notification) {
        smokeOriginalOptions = NSApp.presentationOptions
        buildMenu()
        setup = SetupWindow(url: settings.string(forKey: "url") ?? "")
        setup.window?.delegate = self
        setup.onPresent = { [weak self] choices, url in self?.present(choices: choices, address: url, persist: true) }
        setup.onPreview = { [weak self] url in
            guard let self, let screen = self.setup.window?.screen ?? NSScreen.main else { return }
            self.present(choices: [DisplayChoice(screen: screen)], address: url, persist: true)
        }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 || (event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == ".") {
                self?.returnToSetup(); return nil
            }
            return event
        }
        NotificationCenter.default.addObserver(self, selector: #selector(displaysChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        setup.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        if testing {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.startSmoke() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 60) { if !self.smokeFinished { self.finishSmoke(false, "Timed out") } }
        }
    }
    private func buildMenu() {
        let menu = NSMenu()
        let appItem = NSMenuItem(); menu.addItem(appItem)
        let appMenu = NSMenu(); appItem.submenu = appMenu
        appMenu.addItem(withTitle: "Back to Setup", action: #selector(returnToSetup), keyEquivalent: ".").target = self
        appMenu.addItem(withTitle: "Reload Page", action: #selector(reload), keyEquivalent: "r").target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Display Wall Launcher", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let editItem = NSMenuItem(); menu.addItem(editItem)
        let edit = NSMenu(title: "Edit"); editItem.submenu = edit
        for (title, action, key) in [("Cut", "cut:", "x"), ("Copy", "copy:", "c"), ("Paste", "paste:", "v"), ("Select All", "selectAll:", "a")] {
            edit.addItem(withTitle: title, action: Selector(action), keyEquivalent: key)
        }
        NSApp.mainMenu = menu
    }
    private func present(choices: [DisplayChoice], address: String, persist: Bool) {
        do {
            let url = try WebAddress.parse(address)
            let frame = try DisplayChoice.bounds(choices)
            if persist {
                settings.set(url.absoluteString, forKey: "url")
                settings.set(choices.map { Int($0.id) }, forKey: "displayIDs")
            }
            showWall(frame: frame)
            load(url)
        } catch { setup.status.stringValue = error.localizedDescription }
    }
    private func showWall(frame: NSRect) {
        let window = WallWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.hasShadow = false; window.isMovable = false
        window.backgroundColor = .windowBackgroundColor
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenNone]
        window.level = .normal
        let configuration = WKWebViewConfiguration()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        let view = WKWebView(frame: NSRect(origin: .zero, size: frame.size), configuration: configuration)
        view.autoresizingMask = [.width, .height]
        view.navigationDelegate = self
        window.contentView = view
        web = view; wall = window
        previousOptions = NSApp.presentationOptions
        NSApp.presentationOptions = [.hideDock, .hideMenuBar]
        presenting = true
        window.setFrame(frame, display: true)
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(view)
        setup.window?.orderOut(nil)
        // macOS may constrain an ordinary window on incompatible display configurations.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self, weak window] in
            guard let self, self.presenting, let window else { return }
            if abs(window.frame.width - frame.width) > 2 || abs(window.frame.height - frame.height) > 2 ||
                abs(window.frame.minX - frame.minX) > 2 || abs(window.frame.minY - frame.minY) > 2 {
                self.failed("macOS constrained the presentation window. Check display arrangement and the separate Spaces prerequisite, then log out and back in if changed.")
            }
        }
    }
    private func load(_ url: URL) {
        web?.load(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 35))
        armTimeout()
    }
    private func armTimeout() {
        loadTimer?.invalidate()
        loadTimer = Timer.scheduledTimer(withTimeInterval: 45, repeats: false) { [weak self] _ in
            self?.failed("The page took too long to load. Check the network, then choose Preview or Present to retry.")
        }
    }
    @objc func returnToSetup() {
        loadTimer?.invalidate(); loadTimer = nil
        web?.stopLoading(); web?.navigationDelegate = nil
        wall?.orderOut(nil); wall?.close(); wall = nil; web = nil
        presenting = false
        if let options = previousOptions { NSApp.presentationOptions = options; previousOptions = nil }
        setup?.showWindow(nil)
        setup?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    @objc private func reload() { guard presenting else { return }; web?.reload(); armTimeout() }
    private func failed(_ message: String) {
        returnToSetup()
        setup.status.stringValue = "Could not present: \(message) Choose Preview or Present to retry."
        if testing {
            finishSmoke(smokeFailure && previousOptions == nil && !presenting && NSApp.presentationOptions == smokeOriginalOptions && setup.window?.isVisible == true,
                        "Failure recovery: \(message)")
        }
    }
    @objc private func displaysChanged() {
        let wasPresenting = presenting
        if wasPresenting { returnToSetup() }
        setup.refreshDisplays()
        if wasPresenting { setup.status.stringValue = "Display configuration changed. Select the connected displays and present again." }
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loadTimer?.invalidate()
        if testing { inspectSmoke(webView, attempt: 0) }
    }
    private func inspectSmoke(_ webView: WKWebView, attempt: Int) {
            webView.evaluateJavaScript("JSON.stringify({title:document.title,width:innerWidth,height:innerHeight,text:document.body.innerText.slice(0,180),ready:document.readyState})") { result, error in
                guard error == nil, let result = result as? String else { self.finishSmoke(false, "JavaScript inspection failed"); return }
                print("WEBVIEW \(result)")
                if self.smokeFailure { self.finishSmoke(false, "Failure fixture unexpectedly loaded"); return }
                if self.smoke && !result.contains("Display Wall Launcher fixture") { self.finishSmoke(false, "Fixture missing"); return }
                let hadWall = self.wall?.styleMask == [.borderless] && !NSApp.presentationOptions.isEmpty
                // Exercise the same local Escape monitor used during presentation.
                if let escape = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                                                windowNumber: self.wall?.windowNumber ?? 0, context: nil,
                                                characters: "\u{1b}", charactersIgnoringModifiers: "\u{1b}", isARepeat: false, keyCode: 53) {
                    NSApp.postEvent(escape, atStart: true)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.finishSmoke(hadWall && !self.presenting && self.previousOptions == nil && NSApp.presentationOptions == self.smokeOriginalOptions && self.setup.window?.isVisible == true,
                                     "Borderless preview, web content, Escape return, presentation restoration")
                }
            }
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { failed(error.localizedDescription) }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { failed(error.localizedDescription) }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { failed("Web content process stopped.") }
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if navigationResponse.isForMainFrame, let response = navigationResponse.response as? HTTPURLResponse, response.statusCode >= 400 {
            decisionHandler(.cancel); failed("Server returned HTTP \(response.statusCode)."); return
        }
        decisionHandler(.allow)
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool { NSApp.terminate(nil); return false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { if !presenting { setup.showWindow(nil) }; return true }
    func applicationWillTerminate(_ notification: Notification) {
        if let options = previousOptions { NSApp.presentationOptions = options }
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
    }
    private func startSmoke() {
        if smokeBlank {
            finishSmoke(setup.urlField.stringValue.isEmpty, "Initial URL is blank in the independent settings namespace")
            return
        }
        guard let screen = NSScreen.main else { finishSmoke(false, "No screen"); return }
        if smoke {
            showWall(frame: screen.frame)
            let fixture = Bundle.main.url(forResource: "fixture", withExtension: "html")!
            web?.loadFileURL(fixture, allowingReadAccessTo: fixture.deletingLastPathComponent())
            armTimeout()
        } else {
            present(choices: [DisplayChoice(screen: screen)], address: "http://127.0.0.1:18746/", persist: false)
        }
    }
    private func finishSmoke(_ success: Bool, _ message: String) {
        guard !smokeFinished else { return }; smokeFinished = true
        print("\(success ? "PASS" : "FAIL"): \(message)")
        fflush(stdout)
        if presenting { returnToSetup() }
        exit(success ? 0 : 1)
    }
}
