
using Godot;

namespace vampgd.scenes.player.body;

public record PlayerIntent
{
    public Vector3 Direction { get; init; } = Vector3.Zero;
    public bool Jump { get; init; } = false;
}
