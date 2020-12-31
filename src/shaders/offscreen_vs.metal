#include <metal_stdlib>
using namespace metal;
struct vs_in {
  float4 pos [[attribute(0)]];
  float2 uv [[attribute(1)]];
  float4 data [[attribute(2)]];
};
struct vs_out {
  float4 pos [[position]];
  float2 uv;
  float4 data;
};
vertex vs_out _main(vs_in in [[stage_in]]) {
  vs_out out;
  out.pos = float4((in.pos.xy - 0.5) * float2(2.0, -2.0), 0.5, 1.0);
  out.uv  = in.uv;
  out.data = in.data;
  return out;
}
