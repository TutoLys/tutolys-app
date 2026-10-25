{{flutter_js}}
{{flutter_build_config}}

// Reports real boot milestones to the HTML launch loader in index.html
// (ADR 0018). Each call lands the bar on a milestone and lets it creep
// toward the next one; the Flutter loader continues from wherever it is.
var boot = window.tutolysBoot;
function reach(at, ceiling) {
  if (boot && boot.reach) boot.reach(at, ceiling);
}

reach(0.08, 0.38); // bootstrap running: downloading main.dart.js

_flutter.loader.load({
  onEntrypointLoaded: async function (engineInitializer) {
    reach(0.38, 0.52); // the app's code is here: starting the engine
    const appRunner = await engineInitializer.initializeEngine();
    reach(0.52, 0.6); // engine up: running the app
    await appRunner.runApp();
  },
});
