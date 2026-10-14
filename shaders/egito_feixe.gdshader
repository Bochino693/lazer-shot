shader_type canvas_item;
render_mode blend_add;

// Feixe de energia entre o cristal e um obelisco (scripts/egito_feixes.gd).
// Desenhado como uma faixa: UV.x vai do cristal (0) ao obelisco (1), UV.y
// atravessa. Miolo fino e claro, brilho largo em volta e pulsos que correm
// do cristal para o obelisco; com a carga da descarga os pulsos correm mais
// e o feixe engrossa e estala. A cor e a força vêm da cor do desenho.

uniform float vel = 1.0;        // rapidez dos pulsos
uniform float carga = 0.0;      // 0..1 (descarga do cristal)
uniform float grave = 0.0;

void fragment() {
	float t = TIME;
	float y = abs(UV.y - 0.5) * 2.0;              // 0 no meio, 1 na borda
	float miolo = exp(-y * y * 60.0);
	float halo = exp(-y * y * 5.0) * 0.35;
	float pulso = 0.5 + 0.5 * sin(UV.x * 34.0 - t * (5.0 + 7.0 * vel));
	pulso = pulso * pulso * pulso;
	// estalos com a carga: o miolo treme
	float estalo = carga * carga * (0.5 + 0.5 * sin(t * 47.0 + UV.x * 90.0)) * exp(-y * y * 14.0);
	// sai de dentro do cristal (sem esmaecer) e chega inteiro no obelisco
	float pontas = smoothstep(0.0, 0.012, UV.x) * smoothstep(1.0, 0.985, UV.x);
	float k = (miolo * (0.75 + 0.9 * pulso + 0.4 * grave) + halo * (0.6 + 0.6 * pulso) + estalo) * pontas;
	COLOR = vec4(COLOR.rgb * k * COLOR.a, 1.0);
}
