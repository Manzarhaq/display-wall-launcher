namespace DisplayWallLauncher;

internal static class Checks
{
    public static int Run(string report)
    {
        var results = new List<string>();
        void Expect(bool condition, string name) { if (!condition) throw new Exception(name); results.Add("PASS: " + name); }
        void Reject(Action action, string name)
        {
            try { action(); } catch (ArgumentException) { results.Add("PASS reject: " + name); return; }
            throw new Exception("Should reject: " + name);
        }
        try
        {
            var a = new Rectangle(-1920, 0, 1920, 1080); var b = new Rectangle(0,0,1920,1080);
            Expect(DisplayLayout.Bounds([b,a]) == new Rectangle(-1920,0,3840,1080), "negative-origin two-display union");
            Expect(DisplayLayout.Bounds([b]) == b, "single display");
            Reject(() => DisplayLayout.Bounds([]), "no displays");
            Reject(() => DisplayLayout.Bounds([a,b,b]), "three displays");
            Reject(() => DisplayLayout.Bounds([b,b]), "overlap");
            Reject(() => DisplayLayout.Bounds([a,new Rectangle(20,0,1920,1080)]), "gap");
            Reject(() => DisplayLayout.Bounds([a,new Rectangle(0,0,1920,1200)]), "unequal heights");
            Reject(() => DisplayLayout.Bounds([a,new Rectangle(0,10,1920,1080)]), "vertical offset");
            Expect(DisplayLayout.Address(" https://example.com/wall ").Host == "example.com", "valid trimmed URL");
            foreach (var bad in new[] { "", "example.com", "file:///tmp/index.html", "javascript:alert(1)", "https://user:secret@example.com/" })
                Reject(() => DisplayLayout.Address(bad), "invalid address");
            Expect(new LauncherSettings().Address == "", "blank default settings");
            File.WriteAllLines(report, results); return 0;
        }
        catch (Exception e) { results.Add("FAIL: " + e.Message); File.WriteAllLines(report, results); return 1; }
    }
}
