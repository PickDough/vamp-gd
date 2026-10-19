using System;

using Godot;
using Godot.Collections;

[GlobalClass]
public partial class Words : Resource
{
    [Export]
    public Array<string> words = [];
}
