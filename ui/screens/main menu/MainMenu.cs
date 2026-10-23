using System;
using GdSharpExtensions.TreeQuery;
using Godot;

namespace vampgd.ui.screens.main_menu;

public partial class MainMenu : Control
{
    public override void _EnterTree()
    {
        this.FindUnder<Button>("Play")!.Pressed += () =>
        {
            var map = Map.NewFromLetter("A");
            GetTree().ChangeSceneToNode(map);
        };
    }
}

