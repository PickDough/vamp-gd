using System;
using Godot;

namespace vampgd.scenes.player.body;

public partial class PlayerBody : CharacterBody3D
{
    [Export]
    private float Speed = 5.0f;
    [Export]
    private float JumpVelocity = 6.5f;

    private Node3D mesh = null!;
    private PlayerIntent intent = new();

    public override void _EnterTree()
    {
        mesh = GetNode<Node3D>("Mesh");
    }

    public override void _PhysicsProcess(double delta)
    {
        intent = new PlayerIntent();
        if (Input.IsActionJustPressed("ui_accept") && IsOnFloor())
        {
            intent = intent with { Jump = true };
        }

        var inputDir = Input.GetVector("ui_left", "ui_right", "ui_up", "ui_down");
        var direction = (Transform.Basis * new Vector3(inputDir.X, 0, inputDir.Y)).Normalized();
        intent = intent with { Direction = direction };
        Move((float)delta);
    }

    private void Move(float delta)
    {
        var velocity = Velocity;
        if (!IsOnFloor())
        {
            velocity += GetGravity() * (float)delta;
        }

        if (intent.Jump && IsOnFloor())
        {
            velocity.Y = JumpVelocity;
        }

        if (intent.Direction.Length() > 0.001f)
        {
            velocity.X = intent.Direction.X * Speed;
            velocity.Z = intent.Direction.Z * Speed;
            mesh.LookAt(mesh.GlobalPosition + intent.Direction);
        }
        else
        {
            velocity.X = Mathf.MoveToward(Velocity.X, 0, Speed);
            velocity.Z = Mathf.MoveToward(Velocity.Z, 0, Speed);
        }

        Velocity = velocity;
        MoveAndSlide();
    }
}
