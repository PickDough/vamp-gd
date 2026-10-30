using System.Collections.Generic;
using System.Linq;
using Godot;

namespace vampgd.scenes.player.skills.slice;

public partial class SliceSkill : Node3D
{
    [Export]
    private Godot.Collections.Dictionary<SkillModifier, float> modifiers = [];

    private PackedScene sliceActionScene = ResourceLoader.Load<PackedScene>(
        "res://scenes/player/skills/slice/slice_skill.tscn"
    );

    private List<SliceAction> slices = [];

    // Called when the node enters the scene tree for the first time.
    public override void _Ready()
    {
        slices =
        [
            .. Enumerable
                .Range(0, (int)modifiers[SkillModifier.Count])
                .Select(_ =>
                {
                    var slice = sliceActionScene.Instantiate<SliceAction>();
                    AddChild(slice);
                    return slice;
                }),
        ];

        UpdateModifiers();
    }

    public override void _Process(double delta) { }

    private void UpdateModifiers()
    {
        foreach (
            var (slice, modifier) in from slice in slices
            from modifier in slice.Modifiers.Keys
            select (slice, modifier)
        )
        {
            slice.Modifiers[modifier] = modifiers[modifier];
        }
    }
}

