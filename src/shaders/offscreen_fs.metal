#include <metal_stdlib>
using namespace metal;
struct ps_in {
  float2 uv;
  float4 data;
};
fragment float4 _main(ps_in in [[stage_in]],
                      texture2d<float> tile_tex [[texture(0)]],
                      texture2d<float> pal_tex [[texture(1)]],
                      sampler tile_smp [[sampler(0)]],
                      sampler pal_smp [[sampler(1)]])
{
  float color_code = in.data.x;
  float tile_color = tile_tex.sample(tile_smp, in.uv).x;
  float2 pal_uv = float2(color_code * 4 + tile_color, 0);
  float4 color = pal_tex.sample(pal_smp, pal_uv) * float4(1, 1, 1, in.data.y);
  return color;
}
