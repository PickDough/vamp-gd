using System;

using Godot;

namespace vampgd.scenes.player.body;

public partial class PlayerBody : CharacterBody3D
{
    [Export]
    private float speed = 5.0f;
    [Export]
    private float jumpVelocity = 6.5f;

    [Export]
    private float groundCheck = 1f;
    [Export]
    private float rotationSpeed = 5f;
    [Export]
    private float gravityScale = 1f;

    private RayCast3D rayCast = null!;
    public bool IsCloseToFloor => rayCast.IsColliding();
    private Node3D mesh = null!;
    private PlayerIntent intent = new();

    public override void _EnterTree()
    {
        mesh = GetNode<Node3D>("Mesh");
        rayCast = new RayCast3D
        {
            Enabled = true,
            CollisionMask = 1,
            ExcludeParent = true,
            TargetPosition = Vector3.Down * groundCheck
        };
        AddChild(rayCast);
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
            velocity += GetGravity() * gravityScale * (float)delta;
        }

        if (intent.Jump && IsOnFloor())
        {
            velocity.Y = jumpVelocity;
        }

        if (intent.Direction.Length() > 0.001f)
        {
            velocity.X = intent.Direction.X * speed;
            velocity.Z = intent.Direction.Z * speed;

            var worldDir = GlobalTransform.Basis * intent.Direction;
            var current = mesh.GlobalBasis.Orthonormalized();
            var target = Basis.LookingAt(worldDir, Vector3.Up);

            var angle = current.GetRotationQuaternion().AngleTo(target.GetRotationQuaternion());
            var t = angle > 1e-5f ? Mathf.Min(1f, rotationSpeed * delta / angle) : 1f;

            mesh.GlobalBasis = current.Slerp(target, t).Orthonormalized();
        }
        else
        {
            velocity.X = Mathf.MoveToward(Velocity.X, 0, speed);
            velocity.Z = Mathf.MoveToward(Velocity.Z, 0, speed);
        }

        Velocity = velocity;
        MoveAndSlide();
    }
}
