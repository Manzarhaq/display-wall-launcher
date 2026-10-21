namespace DisplayWallLauncher;

internal static class Program
{
    [STAThread]
    static int Main(string[] args)
    {
        Application.SetHighDpiMode(HighDpiMode.PerMonitorV2);
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);
        if (args.Contains("--self-test")) return Checks.Run(args.Length > 1 ? args[1] : "checks.txt");
        var smoke = args.Contains("--smoke-test");
        Application.Run(new SetupForm(smoke ? (args.Length > 1 ? args[1] : "smoke.txt") : null));
        return Environment.ExitCode;
    }
}
