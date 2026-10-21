namespace DisplayWallLauncher;

internal static class DisplayLayout
{
    public static Rectangle Bounds(IReadOnlyList<Rectangle> frames)
    {
        if (frames.Count is < 1 or > 2 || frames.Any(f => f.Width <= 0 || f.Height <= 0))
            throw new ArgumentException("Select one display, or two adjacent displays.");
        if (frames.Count == 2)
        {
            var sorted = frames.OrderBy(f => f.Left).ToArray();
            var a = sorted[0]; var b = sorted[1];
            if (a.Right != b.Left || a.Top != b.Top || a.Height != b.Height)
                throw new ArgumentException("Arrange extended displays side by side, with touching edges and equal pixel heights, in Windows Settings → System → Display.");
        }
        return frames.Aggregate(Rectangle.Union);
    }

    public static Uri Address(string address)
    {
        if (!Uri.TryCreate(address.Trim(), UriKind.Absolute, out var uri) ||
            uri.Scheme is not ("http" or "https") || string.IsNullOrWhiteSpace(uri.Host) || !string.IsNullOrEmpty(uri.UserInfo))
            throw new ArgumentException("Enter a complete http:// or https:// web address without embedded credentials.");
        return uri;
    }
}
