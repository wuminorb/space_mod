using System;
internal static class Probe2
{
    private static void T(RichTextBuilder b, GameItem item)
    {
        ColorPalette c = (ColorPalette)4367018;
        ColorPalette n = (ColorPalette)(-1);
        b.AddLine(ModHelper.GetLocalized("print_bottle", "tooltip_print_wine", new object[] { 8 }), true, c, false, false, false, false, n, n, n);
        string id = item.identifier;
    }
}
