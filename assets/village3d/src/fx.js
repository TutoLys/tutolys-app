// Shared animation uniforms, and the small shader patches that make things
// move on the GPU: trees and grass sway in the wind, flags ripple.
import * as THREE from 'three';

// One clock for the whole scene. `time` only advances while motion is
// allowed, so reduced motion freezes every shader animation at once.
export const U = {
  uTime: { value: 0 },
  uWind: { value: 0.35 }, // 0 calm … 1 storm
  uNight: { value: 0 }, // 0 day … 1 night
};

/**
 * Sway vertices above the object's origin, more the higher they are.
 * Works for plain and instanced meshes (the instance's position seeds the
 * phase, so a forest never moves in lockstep).
 */
export function addSway(material, { amount = 0.06, heightRef = 2 } = {}) {
  material.onBeforeCompile = (shader) => {
    shader.uniforms.uTime = U.uTime;
    shader.uniforms.uWind = U.uWind;
    shader.vertexShader = shader.vertexShader
      .replace('#include <common>', `#include <common>
        uniform float uTime; uniform float uWind;`)
      .replace('#include <begin_vertex>', `#include <begin_vertex>
        {
          vec3 seed = vec3(0.0);
          #ifdef USE_INSTANCING
            seed = instanceMatrix[3].xyz;
          #endif
          seed += modelMatrix[3].xyz;
          float h = max(position.y, 0.0) / ${heightRef.toFixed(2)};
          float ph = seed.x * 0.37 + seed.z * 0.23;
          float gust = 0.6 + 0.4 * sin(uTime * 0.7 + seed.x * 0.05);
          float k = h * h * ${amount.toFixed(3)} * (0.35 + uWind * 2.2) * gust;
          transformed.x += sin(uTime * (1.6 + uWind * 2.0) + ph) * k;
          transformed.z += cos(uTime * (1.3 + uWind * 1.7) + ph * 1.3) * k * 0.6;
        }`);
  };
  material.customProgramCacheKey = () => 'sway' + amount + heightRef;
  return material;
}

/** Ripple a flag plane (x from 0 at the pole to `length`). */
export function addFlagWave(material, length = 1) {
  material.onBeforeCompile = (shader) => {
    shader.uniforms.uTime = U.uTime;
    shader.uniforms.uWind = U.uWind;
    shader.vertexShader = shader.vertexShader
      .replace('#include <common>', `#include <common>
        uniform float uTime; uniform float uWind;`)
      .replace('#include <begin_vertex>', `#include <begin_vertex>
        {
          float t = clamp(position.x / ${length.toFixed(2)}, 0.0, 1.0);
          float ph = modelMatrix[3].x * 0.7 + modelMatrix[3].z * 0.4;
          float sp = 3.0 + uWind * 6.0;
          transformed.z += sin(position.x * 4.5 - uTime * sp + ph) * 0.12 * t * (0.5 + uWind);
          transformed.y += sin(position.x * 3.0 - uTime * sp * 0.8 + ph) * 0.04 * t;
        }`);
  };
  material.customProgramCacheKey = () => 'flag' + length;
  material.side = THREE.DoubleSide;
  return material;
}

/** Ease helpers. */
export const ease = {
  outCubic: (t) => 1 - Math.pow(1 - t, 3),
  inOutCubic: (t) => (t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2),
  outBack: (t) => { const c1 = 1.70158, c3 = c1 + 1; return 1 + c3 * Math.pow(t - 1, 3) + c1 * Math.pow(t - 1, 2); },
};

/** Critically-damped spring toward a target (frame-rate independent). */
export function damp(current, target, lambda, dt) {
  return THREE.MathUtils.damp(current, target, lambda, dt);
}

export const smooth = (a, b, x) => THREE.MathUtils.smoothstep(x, a, b);
