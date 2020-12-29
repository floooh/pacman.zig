struct vs_in {
    float4 pos: POSITION;
    float2 uv: TEXCOORD0;
    float4 data: TEXCOORD1;
};
struct vs_out {
    float2 uv: UV;
    float4 data: DATA;
    float4 pos: SV_Position;
};
vs_out main(vs_in inp) {
    vs_out outp;
    outp.pos = float4(inp.pos.xy * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
    outp.uv  = inp.uv;
    outp.data = inp.data;
    return outp;
}
