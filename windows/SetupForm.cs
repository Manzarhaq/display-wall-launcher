using Microsoft.Win32;
using System.Diagnostics;

namespace DisplayWallLauncher;

internal sealed class SetupForm : Form
{
    private readonly TextBox address = new() { Dock = DockStyle.Top, PlaceholderText = "https://…", AccessibleName = "Web address" };
    private readonly CheckedListBox displays = new() { Dock = DockStyle.Fill, CheckOnClick = true, IntegralHeight = false };
    private readonly Label status = new() { AutoSize = true, MaximumSize = new Size(670, 0) };
    private readonly Button present = new() { Text = "Present", AutoSize = true };
    private readonly Button preview = new() { Text = "Preview on this screen", AutoSize = true };
    private WallForm? wall;
    private readonly string? smokeReport;
    private bool closing;
    private sealed record Choice(Screen Screen) { public override string ToString() => $"{Screen.DeviceName} · {Screen.Bounds.Width} × {Screen.Bounds.Height} px · x {Screen.Bounds.X}, y {Screen.Bounds.Y}"; }

    public SetupForm(string? smokeReport = null)
    {
        this.smokeReport = smokeReport;
        Text = "Display Wall Launcher";
        ClientSize = new Size(740, 540); MinimumSize = new Size(680, 580);
        StartPosition = FormStartPosition.CenterScreen;
        Font = new Font("Segoe UI", 10); AutoScaleMode = AutoScaleMode.Dpi;
        var layout = new TableLayoutPanel { Dock = DockStyle.Fill, Padding = new Padding(24), ColumnCount = 1, RowCount = 9 };
        layout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        for (var i = 0; i < 9; i++) layout.RowStyles.Add(new RowStyle(i == 4 ? SizeType.Percent : SizeType.AutoSize, i == 4 ? 100 : 0));
        layout.Controls.Add(new Label { Text = "Display Wall Launcher", Font = new Font(Font.FontFamily, 22, FontStyle.Bold), AutoSize = true, Margin = new Padding(0,0,0,12) }, 0, 0);
        layout.Controls.Add(new Label { Text = "One continuous web canvas across your selected displays.", AutoSize = true, Margin = new Padding(0,0,0,20) }, 0, 1);
        layout.Controls.Add(new Label { Text = "Web address", AutoSize = true }, 0, 2);
        layout.Controls.Add(address, 0, 3);
        layout.Controls.Add(displays, 0, 4);
        layout.Controls.Add(new Label { Text = "Select one or two extended displays. For two, align them side by side with equal pixel heights. The app never changes your display settings.", AutoSize = true, MaximumSize = new Size(670,0), Margin = new Padding(0,12,0,12) }, 0, 5);
        var actions = new FlowLayoutPanel { AutoSize = true, Dock = DockStyle.Fill };
        actions.Controls.Add(preview); actions.Controls.Add(present);
        var runtime = new LinkLabel { Text = "Get Microsoft WebView2 Runtime", AutoSize = true, Margin = new Padding(10,8,0,0) };
        runtime.LinkClicked += (_, _) => Process.Start(new ProcessStartInfo("https://developer.microsoft.com/en-us/microsoft-edge/webview2/#download-section") { UseShellExecute = true });
        actions.Controls.Add(runtime); layout.Controls.Add(actions,0,6);
        layout.Controls.Add(new Label { Text = "Escape / Ctrl+. returns to setup · Ctrl+R reloads · Ctrl+Q / Alt+F4 quits", AutoSize = true, Margin = new Padding(0,12,0,12) },0,7);
        layout.Controls.Add(status,0,8); Controls.Add(layout);
        address.Text = smokeReport is null ? SettingsStore.Load().Address : "";
        present.Click += (_,_) => Present(displays.CheckedItems.Cast<Choice>().Select(c => c.Screen).ToArray());
        preview.Click += (_,_) => Present([Screen.FromControl(this)]);
        SystemEvents.DisplaySettingsChanged += DisplaysChanged;
        RefreshDisplays(); status.Text = "Enter a web address, then preview or present.";
        FormClosing += (_,_) => { closing = true; SystemEvents.DisplaySettingsChanged -= DisplaysChanged; wall?.Dispose(); };
        Shown += async (_,_) => { if (smokeReport is not null) await RunSmokeAsync(); };
    }
    private void RefreshDisplays()
    {
        var chosen = displays.CheckedItems.Cast<Choice>().Select(c => c.Screen.DeviceName).ToArray();
        if (chosen.Length == 0 && smokeReport is null) chosen = SettingsStore.Load().Displays ?? [];
        displays.Items.Clear();
        foreach (var screen in Screen.AllScreens) displays.Items.Add(new Choice(screen), chosen.Contains(screen.DeviceName) || Screen.AllScreens.Length == 1);
    }
    private async void Present(Screen[] selected)
    {
        try
        {
            var uri = DisplayLayout.Address(address.Text);
            var bounds = DisplayLayout.Bounds(selected.Select(s => s.Bounds).ToArray());
            try { SettingsStore.Save(new(uri.AbsoluteUri, selected.Select(s => s.DeviceName).ToArray())); }
            catch (Exception e) when (e is IOException or UnauthorizedAccessException) { status.Text = "Settings could not be saved; presentation will still open."; }
            await OpenWallAsync(bounds, uri);
        }
        catch (Exception e) { ReturnToSetup(e.Message); }
    }
    private async Task OpenWallAsync(Rectangle bounds, Uri? uri)
    {
        present.Enabled = preview.Enabled = false;
        var current = new WallForm(bounds);
        wall = current;
        current.BackRequested += message => { if (wall == current) ReturnToSetup(message); };
        current.QuitRequested += () => Close();
        current.Show(); current.Bounds = bounds;
        if (current.Bounds != bounds) throw new InvalidOperationException("Windows constrained the presentation window. Check display arrangement and scaling.");
        current.Activate(); Hide();
        await current.LoadAsync(uri);
    }
    private void ReturnToSetup(string message = "Ready. Choose Preview or Present to try again.")
    {
        if (closing) return;
        var previous = wall; wall = null;
        previous?.Dispose(); Show(); Activate();
        present.Enabled = preview.Enabled = true; status.Text = message;
    }
    private void DisplaysChanged(object? sender, EventArgs e)
    {
        if (IsDisposed || !IsHandleCreated) return;
        BeginInvoke(() => { ReturnToSetup("Display configuration changed. Select the connected displays and present again."); RefreshDisplays(); });
    }
    protected override bool ProcessCmdKey(ref Message msg, Keys keyData)
    {
        if (keyData == (Keys.Control | Keys.Q)) { Close(); return true; }
        return base.ProcessCmdKey(ref msg, keyData);
    }
    private async Task RunSmokeAsync()
    {
        var results = new List<string>();
        try
        {
            if (address.Text != "") throw new Exception("Initial test address was not blank");
            results.Add("PASS: blank initial address");
            await OpenWallAsync(Screen.FromControl(this).Bounds, null);
            var current = wall ?? throw new Exception("Wall did not open");
            await current.Ready.WaitAsync(TimeSpan.FromSeconds(40));
            if (current.FormBorderStyle != FormBorderStyle.None) throw new Exception("Wall has borders");
            var title = await current.ReadTitleAsync();
            if (!title.Contains("Display Wall Launcher fixture")) throw new Exception("Fixture not rendered");
            results.Add("PASS: actual WebView2 fixture loaded in borderless window");
            current.RequestBack();
            if (!Visible || wall is not null) throw new Exception("Back did not restore setup");
            results.Add("PASS: return to setup");
            await OpenWallAsync(Screen.FromControl(this).Bounds, new Uri("http://127.0.0.1:18746/"));
            var failureWall = wall;
            if (failureWall is not null) await failureWall.Ready.WaitAsync(TimeSpan.FromSeconds(40));
            if (!Visible || wall is not null) throw new Exception("Failed load did not recover");
            results.Add("PASS: failed-load recovery");
            Environment.ExitCode = 0;
        }
        catch (Exception e) { results.Add("FAIL: " + e.Message); Environment.ExitCode = 1; }
        File.WriteAllLines(smokeReport!, results); Close();
    }
}
