shader_type canvas_item;

void fragment() {
    vec3 c = textureLod(SCREEN_TEXTURE, SCREEN_UV, 0.0).rgb;
	vec4 t = texture(TEXTURE, UV);

	if(t.a > 0.0 && c.r > 0.3 && c.g > 0.2 && c.g < 0.5 && c.b < 0.2)
	{
		COLOR.rgb -= c;
	}
	else
	{
		COLOR = t;
	}
}