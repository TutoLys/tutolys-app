/// Where the HTML loader in `web/index.html` had got to when Flutter's first
/// frame replaced it, so the Flutter loader continues from the same point —
/// the same bar width and the same line of copy — instead of starting over.
typedef BootHandoff = ({double progress, int messageIndex});
