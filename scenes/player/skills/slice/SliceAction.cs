using System.Linq;
using GdSharpExtensions.TreeQuery;
using Godot;
using Godot.Collections;
using vampgd.scenes.enemies;

namespace vampgd.scenes.player.skills.slice;

public partial class SliceAction : Area3D
{
    private AnimationPlayer animationPlayer = null!;

    public Dictionary<SkillModifier, float> Modifiers { get; private set; } = [];

    public override void _EnterTree()
    {
        animationPlayer = this.FindUnder<AnimationPlayer>()!;
    }

    public override void _Ready()
    {
        animationPlayer.AnimationFinished += (_) =>
        {
            var enemies = from body in GetOverlappingBodies() where body is Enemy select body as Enemy;

            foreach (var enemy in enemies)
            {
                enemy.TakeDamage(Modifiers[SkillModifier.Damage]);
            }
        };
    }

    public void Execute()
    {
        animationPlayer.Play("slice");
    }
}

