struct vs_out {
    float2 uv: UV;
    float4 pos: SV_Position;
};
vs_out main(float4 pos: POSITION) {
    vs_out outp;
    outp.pos = float4((pos.xy - 0.5) * float2(2.0, -2.0), 0.0, 1.0);
    outp.uv = pos.xy;
    return outp;
}