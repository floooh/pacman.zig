Texture2D<float4> tile_tex: register(t0);
Texture2D<float4> pal_tex: register(t1);
sampler tile_smp: register(s0);
sampler pal_smp: register(s1);
float4 main(float2 uv: UV, float4 data: DATA): SV_Target0 {
    float color_code = data.x;
    float tile_color = tile_tex.Sample(tile_smp, uv).x;
    float2 pal_uv = float2(color_code * 4 + tile_color, 0);
    float4 color = pal_tex.Sample(pal_smp, pal_uv) * float4(1, 1, 1, data.y);
    return color;
}