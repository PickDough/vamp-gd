using Godot;

namespace vampgd.scenes.player.attributes;

[GlobalClass]
public partial class PlayerAttributes : Resource
{
    [Export]
    public float SpeedModifier { get; set; } = 1.0f;
    [Export]
    public float jumpVelocityModifier { get; set; } = 1.0f;
    [Export]
    public int ExtraJumpsCount { get; set; } = 0;
    [Export]
    public int ExperiencePoints { get; set; } = 0;
    [Export]
    public int Gold { get; set; } = 0;
}