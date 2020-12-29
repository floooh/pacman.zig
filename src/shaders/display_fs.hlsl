Texture2D<float4> tex: register(t0);
sampler smp: register(s0);
float4 main(float2 uv: UV): SV_Target0 {
    return tex.Sample(smp, uv);
}