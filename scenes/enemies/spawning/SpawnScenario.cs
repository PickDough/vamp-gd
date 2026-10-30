using System.Collections.Generic;
using Godot;

namespace vampgd.enemies.spawning;

[GlobalClass]
public partial class SpawnScenario : Resource
{
    [Export]
    public float StartTime = 0f;

    [Export]
    public float RadiusAroundPlayer = 100f;

    [Export]
    public float AmountPerTick = 1f;

    [Export]
    public int MaxEnemies = 10;

    [Export]
    public List<PackedScene> EnemyScenes = [];
}

