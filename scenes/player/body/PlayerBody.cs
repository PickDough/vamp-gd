using System;
using Godot;

public partial class PlayerBody : CharacterBody3D
{
    [Export]
    public float Speed = 5.0f;

    [Export]
    public float JumpVelocity = 6.5f;

    [Export]
    public float groundCheck = 1f;

    private Node3D mesh = null!;
    private RayCast3D rayCast = null!;

    public bool IsCloseToFloor => rayCast.IsColliding();

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
        Vector3 velocity = Velocity;

        // Add the gravity.
        if (!IsOnFloor())
        {
            velocity += GetGravity() * (float)delta;
        }

        // Handle Jump.
        if (Input.IsActionJustPressed("ui_accept") && IsOnFloor())
        {
            velocity.Y = JumpVelocity;
        }

        // Get the input direction and handle the movement/deceleration.
        // As good practice, you should replace UI actions with custom gameplay actions.
        Vector2 inputDir = Input.GetVector("ui_left", "ui_right", "ui_up", "ui_down");
        Vector3 direction = (Transform.Basis * new Vector3(inputDir.X, 0, inputDir.Y)).Normalized();
        if (direction != Vector3.Zero)
        {
            velocity.X = direction.X * Speed;
            velocity.Z = direction.Z * Speed;
            mesh.LookAt(mesh.GlobalPosition + direction);
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
