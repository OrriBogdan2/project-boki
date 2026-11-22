// The hit flash's glow, shared by the hero surfaces (hero_toon, warden_card): 0.9 of the flash colour, and more on
// pale surfaces. An ice-white or pink body is already near the flash's white, so it reads by going past it: brighter,
// and over the glow threshold it blooms. A dark body has room to go white and keeps the plain glow.
const float FLASH_GLOW = 0.9;    // the glow on a dark or mid surface
const float FLASH_PALE = 1.6;    // up to this much more on a pale one (linear luminance 0.15 .. 0.6)

vec3 hit_flash_glow(vec3 c, vec3 col, float f) {
	return col * f * (FLASH_GLOW + FLASH_PALE * smoothstep(0.15, 0.6, dot(c, vec3(0.3, 0.59, 0.11))));
}
