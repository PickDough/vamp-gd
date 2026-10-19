using System;

using GdSharpExtensions.TreeQuery;

using Godot;

namespace vampgd.ui.screens.main_menu;

public partial class MainMenu : Control
{
    public override void _EnterTree()
    {
        var map = Map.NewFromLetter('A');
        this.FindUnder<Button>("Play")!.Pressed += () => GetTree().ChangeSceneToNode(map);
    }

}
