using System.Text.Json;

namespace DisplayWallLauncher;

internal sealed record LauncherSettings(string Address = "", string[]? Displays = null);
internal static class SettingsStore
{
    public static string Root => Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "DisplayWallLauncher");
    public static string FilePath => Path.Combine(Root, "settings.json");
    public static LauncherSettings Load()
    {
        try { return JsonSerializer.Deserialize<LauncherSettings>(File.ReadAllText(FilePath)) ?? new(); }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException or JsonException) { return new(); }
    }
    public static void Save(LauncherSettings settings)
    {
        Directory.CreateDirectory(Root);
        var temp = FilePath + ".tmp";
        File.WriteAllText(temp, JsonSerializer.Serialize(settings));
        File.Move(temp, FilePath, overwrite: true);
    }
}
