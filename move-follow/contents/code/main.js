function moveAndFollow(desktop) {
  const win = workspace.activeWindow;
  if (!win) {
    return;
  }

  const desktops = workspace.desktops;
  if (desktop < 1 || desktop > desktops.length) {
    return;
  }

  win.desktops = [desktops[desktop - 1]];
  workspace.currentDesktop = desktops[desktop - 1];
  workspace.activeWindow = win;
}

registerShortcut("MoveFollow1", "Move Follow Desktop 1", "Alt+F1", () =>
  moveAndFollow(1),
);

registerShortcut("MoveFollow2", "Move Follow Desktop 2", "Alt+F2", () =>
  moveAndFollow(2),
);

registerShortcut("MoveFollow3", "Move Follow Desktop 3", "Alt+F3", () =>
  moveAndFollow(3),
);

registerShortcut("MoveFollow4", "Move Follow Desktop 4", "Alt+F4", () =>
  moveAndFollow(4),
);

registerShortcut("MoveFollow5", "Move Follow Desktop 5", "Alt+F5", () =>
  moveAndFollow(5),
);
