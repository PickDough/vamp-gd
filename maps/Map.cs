using System;

using GdSharpExtensions.TreeQuery;

using Godot;



[Tool]
public partial class Map : Node3D
{


    public static Map NewFromLetter(char letter)
    {
        var mapScene = ResourceLoader.Load<PackedScene>("res:/maps/map.tscn");
        var map = mapScene.Instantiate<Map>();

        return map;
    }

    private MeshInstance3D textMesh = null!;

    public override void _EnterTree()
    {
        textMesh = this.FindUnder<MeshInstance3D>("TextMesh")!;
    }

    public override void _Ready()
    {
        textMesh.Mesh = new TextMesh()
        {
            Text = "A",
            FontSize = 64,
            PixelSize = 4,
            Depth = 12
        };
    }

}
