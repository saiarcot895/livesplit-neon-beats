state("Neon Beats") {}

init {
    vars.timer = null;
    IntPtr ptr = IntPtr.Zero;

    // Find out where the game state struct is located
    foreach (MemoryBasicInformation mbi in game.MemoryPages()) {
        var scanner = new SignatureScanner(game, mbi.BaseAddress, (int)mbi.RegionSize.ToUInt64());

        // There's multiple parts of memory that have this instruction sequence.
        // One of them has a pointer to the actual game state struct that we're
        // interested in.
        IEnumerable<IntPtr> candidatePtrs = scanner.ScanAll(new SigScanTarget(12, // Targeting byte 12
                    "41 FF D3",          // call *%r11
                    "48 83 C4 20",       // add 0x20, %rsp
                    "85 C0",             // test %eax, %eax
                    "74 0C",             // je [12 bytes ahead]
                    "B8 ?? ?? ?? ??",    // mov [game state struct], %eax
                    "48 8B 4D F8",       // mov -0x8(%rbp), %rcx
                    "48 89 08",          // mov %rcx, (%rax)
                    "C9",                // leave
                    "C3"                 // ret
                    ));

        foreach (IntPtr candidatePtr in candidatePtrs) {
			// Check to see if _startSources is not null
            var deepCandidatePtr = new DeepPointer(candidatePtr, 0x0, 0x20);
			print("Checking " + candidatePtr.ToString("x"));
            if (deepCandidatePtr.Deref<long>(game) != 0) {
				ptr = candidatePtr;
                break;
            }
        }

        if (ptr != IntPtr.Zero) {
            print("Scanner found the game state struct: " + ptr.ToString("x"));
            vars.level_id = new MemoryWatcher<int>(new DeepPointer(ptr, 0x0, 0x98));
            vars.in_game = new MemoryWatcher<bool>(new DeepPointer(ptr, 0x0, 0xb4));
            vars.collectibles = new MemoryWatcher<int>(new DeepPointer(ptr, 0x0, 0xb8));
            vars.death_counter = new MemoryWatcher<int>(new DeepPointer(ptr, 0x0, 0xbc));
            vars.timer = new MemoryWatcher<float>(new DeepPointer(ptr, 0x0, 0xc0));
			vars.paused = new MemoryWatcher<bool>(new DeepPointer(ptr, 0x0, 0xd4));
            break;
        }
    }
    if (ptr == IntPtr.Zero) {
        throw new Exception("Could not find the game state struct!");
    }
}

update {
    if (vars.timer == null) return false; // Init not yet done

    vars.timer.Update(game);
    vars.level_finished.Update(game);
    vars.level_id.Update(game);
    vars.collectibles.Update(game);
    vars.death_counter.Update(game);
	vars.paused.Update(game);
}

isLoading {
    return true; // Disable gameTime approximation
}

gameTime {
    return TimeSpan.FromSeconds(vars.timer.Old);
}

reset {
	return vars.level_id.Old + 1 != vars.level_id.Current && vars.level_id.Old != vars.level_id.Current;
}

start {
    return vars.in_game.Current == true;
}

split {
    return vars.level_id.Old + 1 == vars.level_id.Current;
}
