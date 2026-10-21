using Microsoft.Web.WebView2.Core;
using Microsoft.Web.WebView2.WinForms;

namespace DisplayWallLauncher;

internal sealed class WallForm : Form
{
    private readonly WebView2 web = new() { Dock = DockStyle.Fill };
    private readonly System.Windows.Forms.Timer timeout = new() { Interval = 45000 };
    private readonly TaskCompletionSource<bool> loaded = new(TaskCreationOptions.RunContinuationsAsynchronously);
    public Task Ready => loaded.Task;
    public event Action<string>? BackRequested;
    public event Action? QuitRequested;

    public WallForm(Rectangle bounds)
    {
        FormBorderStyle = FormBorderStyle.None; StartPosition = FormStartPosition.Manual;
        AutoScaleMode = AutoScaleMode.None; Bounds = bounds;
        TopMost = true; Text = "Display Wall Launcher";
        Controls.Add(web);
        timeout.Tick += (_,_) => QueueFailure("The page took too long to load. Check the network, then preview or present to retry.");
        FormClosing += (_,_) => QuitRequested?.Invoke();
    }
    public async Task LoadAsync(Uri? address)
    {
        try
        {
            timeout.Start();
            _ = CoreWebView2Environment.GetAvailableBrowserVersionString();
            var environment = await CoreWebView2Environment.CreateAsync(null, Path.Combine(SettingsStore.Root, "WebView2"));
            if (IsDisposed) return;
            await web.EnsureCoreWebView2Async(environment);
            if (IsDisposed) return;
            web.CoreWebView2.Settings.IsStatusBarEnabled = false;
            web.CoreWebView2.Settings.AreDefaultContextMenusEnabled = false;
            web.CoreWebView2.Settings.AreBrowserAcceleratorKeysEnabled = false;
            web.CoreWebView2.NewWindowRequested += (_,e) => e.Handled = true;
            web.CoreWebView2.ProcessFailed += (_,_) => QueueFailure("The web content process stopped. Preview or present to retry.");
            web.CoreWebView2.NavigationStarting += (_,_) => timeout.Start();
            web.CoreWebView2.NavigationCompleted += (_,e) =>
            {
                timeout.Stop();
                if (!e.IsSuccess || e.HttpStatusCode >= 400)
                    QueueFailure($"Could not load the page ({(e.HttpStatusCode >= 400 ? "HTTP " + e.HttpStatusCode : e.WebErrorStatus.ToString())}). Check the address and network, then preview or present to retry.");
                else loaded.TrySetResult(true);
            };
            // WinForms forwards WebView2 accelerator keys through KeyDown.
            // Queue actions to avoid disposing a webview during its input callback.
            web.KeyDown += (_,e) =>
            {
                Action? action = e.KeyCode == Keys.Escape || (e.Control && e.KeyCode == Keys.OemPeriod) ? () => RequestBack() :
                    e.Control && e.KeyCode == Keys.R ? Reload :
                    e.Control && e.KeyCode == Keys.Q ? () => QuitRequested?.Invoke() : null;
                if (action is null) return;
                e.Handled = true; e.SuppressKeyPress = true;
                BeginInvoke(action);
            };
            if (address is null)
                web.NavigateToString("<!doctype html><html><head><title>Display Wall Launcher fixture</title></head><body><h1>Display Wall Launcher fixture</h1><p>Local wrapper validation only.</p></body></html>");
            else web.CoreWebView2.Navigate(address.AbsoluteUri);
            web.Focus();
        }
        catch (WebView2RuntimeNotFoundException) { QueueFailure("Microsoft WebView2 Runtime is missing. Use ‘Get Microsoft WebView2 Runtime’ in setup to install the official Evergreen Runtime, then try again."); }
        catch (Exception e) { if (!IsDisposed) QueueFailure("Could not initialize the webview: " + e.Message); }
    }
    public void RequestBack(string message = "Ready. Choose Preview or Present to try again.") => BackRequested?.Invoke(message);
    public async Task<string> ReadTitleAsync() => await web.ExecuteScriptAsync("document.title");
    private void QueueFailure(string message)
    {
        timeout.Stop();
        if (IsDisposed || !IsHandleCreated) return;
        BeginInvoke(() => { RequestBack(message); loaded.TrySetResult(false); });
    }
    private void Reload() { if (!IsDisposed) { timeout.Start(); web.CoreWebView2?.Reload(); } }
    protected override bool ProcessCmdKey(ref Message msg, Keys keyData)
    {
        if (keyData == Keys.Escape || keyData == (Keys.Control | Keys.OemPeriod)) { RequestBack(); return true; }
        if (keyData == (Keys.Control | Keys.Q)) { QuitRequested?.Invoke(); return true; }
        if (keyData == (Keys.Control | Keys.R)) { Reload(); return true; }
        return base.ProcessCmdKey(ref msg, keyData);
    }
    protected override void Dispose(bool disposing)
    {
        if (disposing) { timeout.Stop(); timeout.Dispose(); web.Dispose(); }
        base.Dispose(disposing);
    }
}
