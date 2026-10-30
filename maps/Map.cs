using System;

using GdSharpExtensions.TreeQuery;

using Godot;

using vampgd.scenes.player.body;

[Tool]
public partial class Map : Node3D
{

    private string letter = "";

    public static Map NewFromLetter(string letter)
    {
        var mapScene = ResourceLoader.Load<PackedScene>("res://maps/map.tscn");
        var map = mapScene.Instantiate<Map>();
        map.letter = letter;

        return map;
    }
    
    private const float EdgeOffset = 2f;
    private const int PickAttempts = 24;
    private const int EdgeSamples = 8;
    private const float OnMeshSlack = 0.35f;
    private const string PlayerScenePath = "res://scenes/player/body/player_body.tscn";

    private MeshInstance3D textMesh = null!;
    private NavigationRegion3D navigationRegion = null!;
    private VoxelGI voxelGI = null!;

    public override void _EnterTree()
    {
        textMesh = this.FindUnder<MeshInstance3D>("TextMesh")!;
        navigationRegion = this.FindUnder<NavigationRegion3D>()!;
        voxelGI = this.FindUnder<VoxelGI>()!;
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
        if (Engine.IsEditorHint())
            return;

        textMesh.CreateTrimeshCollision();
        voxelGI.CallDeferred(VoxelGI.MethodName.Bake); 
        navigationRegion.BakeFinished += OnBakeFinished;
        navigationRegion.BakeNavigationMesh();
    }

    public Vector3 RandomPosition() => PickRandomPointInsetFromEdges();

    private async void OnBakeFinished()
    {
        if (Engine.IsEditorHint())
            return;

        await ToSignal(GetTree(), SceneTree.SignalName.PhysicsFrame);
        if (!IsInsideTree())
            return;

        var playerScene = ResourceLoader.Load<PackedScene>(PlayerScenePath);
        var player = playerScene.Instantiate<PlayerBody>();
        AddChild(player);
        player.GlobalPosition = PickRandomPointInsetFromEdges();
    }

    private Vector3 PickRandomPointInsetFromEdges()
    {
        var region = navigationRegion.GetRid();
        var layers = navigationRegion.NavigationLayers;
        var fallback = NavigationServer3D.RegionGetRandomPoint(region, layers, true);

        for (var i = 0; i < PickAttempts; i++)
        {
            var point = NavigationServer3D.RegionGetRandomPoint(region, layers, true);
            if (IsInsetFromEdges(region, point))
                return point;
        }

        return fallback;
    }

    private static bool IsInsetFromEdges(Rid region, Vector3 point)
    {
        for (var i = 0; i < EdgeSamples; i++)
        {
            var angle = i * Mathf.Tau / EdgeSamples;
            var sample = point + new Vector3(Mathf.Cos(angle), 0f, Mathf.Sin(angle)) * EdgeOffset;
            var closest = NavigationServer3D.RegionGetClosestPoint(region, sample);
            if (closest.DistanceSquaredTo(sample) > OnMeshSlack * OnMeshSlack)
                return false;
        }

        return true;
    }
}
