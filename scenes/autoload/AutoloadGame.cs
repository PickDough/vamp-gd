using System;
using Godot;

namespace vampgd.scenes.globals;

public partial class AutoloadGame : Node
{
    public Random RNG { get; private set; } = new Random();

    public override void _EnterTree() { }
}

