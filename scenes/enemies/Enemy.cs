using System;
using Godot;

namespace vampgd.scenes.enemies;

public partial class Enemy : CharacterBody3D
{
    [Export]
    private float baseHealth = 10f;

    private float health = 0f;

    // Called when the node enters the scene tree for the first time.
    public override void _Ready() { }

    // Called every frame. 'delta' is the elapsed time since the previous frame.
    public override void _Process(double delta) { }

    public void TakeDamage(float damage)
    {
        health -= damage;
        if (health <= 0)
        {
            QueueFree();
        }
    }
}

