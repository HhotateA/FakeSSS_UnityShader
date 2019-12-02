Shader "HOTATE/SSS/Write"
{
	Properties
    {
		[HideInInspector] _Stencil ("Stencil", Float) = 750
        _MainTex ("Texture", 2D) = "white" {}
        _Color ("Color", Color) = (1,1,1,1)
        
        _SSSColor ("SSSColor", Color) = (0.772,0.514,0.773,1)
        _SSSBlend ("SSSBlend", range(0,1)) = 0.585
        _Opacity ("Opacity", range(0,1)) = 0.067
        _Decay ("Decay", range(1,30)) = 6.3
        _Reflex ("Reflex", range(0,1)) = 0.5

        _BumpMap ("BumpMap", 2D) = "Bump" {}
        _BumpScale ("BumpScale", float) = 0

        _Toon ("Unlit",Range(0,1)) = 0

        _Metalic ("Metalic", range(0,1)) = 0.56
        _Roughness ("Roughness", range(0,1)) = 0
        _HalfLambert ("HalfLambert", range(0,1)) = 0

		_PointLightPower ("PointLightPower", range(0,1)) = 0.5
		_PointLightTransparent ("PointLightTransparent", range(1,30)) = 20
		_Balance ("Balance", range(0,1)) = 0.75

        _ShadeColor0 ("1st Shade Color", Color) = (0.97, 0.81, 0.86, 1)
        _ShadeShift0 ("1st Shade Shift", Range(-1, 1)) = 0.173
        _ShadeToony0 ("1st Shade Toony", Range(0, 1)) = 0.383
		_Shade1Power0 ("ShadowPower 0",float) = 2
        _ShadeColor1 ("2nd Shade Color", Color) = (0.9, 0.61, 0.68, 1)
        _ShadeShift1 ("2nd Shade Shift", Range(-1, 1)) = 0.288
        _ShadeToony1 ("2nd Shade Toony", Range(0, 1)) = 0.829
		_Shade1Power1 ("ShadowPower 1",float) = 1
	}
	SubShader
	{
		Tags{"Queue"="Geometry+51"}
        Stencil
        {
            Ref [_Stencil]
            Comp Equal
        }
		Pass
		{
			Cull Front
			ZWrite On
            ZTest GEqual
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			// make fog work
			
			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
    			float4 projPos : TEXCOORD1;
				float4 centerDepth : TEXCOORD2;
				float3 wPos : World_Pos;
			};
            
            sampler2D _MainTex;
            float4 _MainTex_ST;
            fixed4 _Color;
			
			v2f vert (appdata v)
			{
				v2f o;
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.projPos = ComputeScreenPos(o.vertex);
				COMPUTE_EYEDEPTH(o.projPos.z);
				o.centerDepth = UnityViewToClipPos(float4(0,0,0,1));
				o.wPos = mul(UNITY_MATRIX_M,v.vertex).xyz;
				return o;
			}
			
			fixed4 frag (v2f i) : COLOR
			{
                fixed4 col = tex2D(_MainTex, i.uv) * _Color;
                clip(col.a-0.5);
				float frontDepth = distance(i.wPos,_WorldSpaceCameraPos);
				return fixed4(frontDepth.xxx,1);
			}
			ENDCG
		}

		GrabPass{"_BackDepthTexture"}
        
        Pass
        {
            Tags { "LightMode"="ForwardBase"}
            ZWrite On
            Cull Back
			ZTest LEqual
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fwdbase
            #pragma multi_compile_fog
            
            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            #include "AutoLight.cginc"
            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
            };
            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                SHADOW_COORDS(2) // put shadows data into TEXCOORD1
                float4 pos : SV_POSITION;
                float3 normal : NORMAL;
                float3 tangent : TANGENT;
                float3 bitTangent : Bit_Tangent;
                float4 grabPos : Grab_Pos;
                float3 wPos : World_Pos;
    			float4 projPos : Projextion_Pos;
            };

            sampler2D _BackDepthTexture;
            sampler2D _MainTex;
            float4 _MainTex_ST;
            fixed4 _Color;
            sampler2D _BumpMap;
            float _BumpScale;
            float _HalfLambert;
            float _Metalic;
            float _Roughness;
            fixed4 _SSSColor;
            float _SSSBlend;
            float _Opacity;
            float _Decay;
            float _Toon;
            float _Reflex;

            fixed4 _ShadeColor0, _ShadeColor1;
            float _ShadeShift0, _ShadeShift1;
            float _ShadeToony0, _ShadeToony1;
            
            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.normal = normalize(UnityObjectToWorldNormal(v.normal));
                o.tangent = normalize(UnityObjectToWorldDir(v.tangent));
                o.bitTangent = normalize(cross(o.normal, o.tangent) * v.tangent.w);
                o.grabPos = ComputeGrabScreenPos(o.pos);
                o.wPos = mul(UNITY_MATRIX_M,v.vertex).xyz;
				o.projPos = ComputeScreenPos(o.pos);
				COMPUTE_EYEDEPTH(o.projPos.z);
                UNITY_TRANSFER_FOG(o,o.pos);
                TRANSFER_SHADOW(o)
                return o;
            }
            
            fixed4 frag (v2f i) : COLOR
            {
                float frontDepth = distance(i.wPos,_WorldSpaceCameraPos);
                float backDepth = tex2Dproj(_BackDepthTexture,i.grabPos);
                float depth = backDepth - frontDepth;
                float3 viewDir = normalize(i.wPos - _WorldSpaceCameraPos);
                float3x3 tangentTransform = float3x3(i.tangent,i.bitTangent,i.normal);
                float3 bump = UnpackScaleNormal(tex2D(_BumpMap, i.uv), _BumpScale); //sample Bumpmap
                float3 normalDir = normalize(mul( bump, tangentTransform));
                float3 lightDir = _WorldSpaceLightPos0.xyz - i.wPos .xyz*_WorldSpaceLightPos0.w;
                float dotNV = max(0,dot(normalDir,viewDir));
                float dotNL = dot(normalDir,lightDir);
                float lambert = saturate(lerp(dotNL,dotNL * 2.0 - 1.0, _HalfLambert));
                float mlambert = saturate(lerp(-dotNL,-dotNL * 2.0 - 1.0, _HalfLambert))*_Reflex+(1-_Reflex);
                UNITY_LIGHT_ATTENUATION(shadowAtt, i, i.wPos.xyz);
                // sample the texture
                fixed4 col = tex2D(_MainTex, i.uv) * _Color;
                clip(col.a-0.5);
                fixed3 pbr = calcPBRCol( col,
                                        _Metalic, _Roughness,
                                        dotNV, viewDir, normalDir, lightDir,
                                        lambert, _LightColor0.rgb*shadowAtt*shadowAtt);

                fixed3 toon = calcToonCol( col,_ShadeShift0,_ShadeToony0,_ShadeColor0,_ShadeShift1,_ShadeToony1,_ShadeColor1,lambert,_LightColor0.rgb,ShadeSH9(half4(normalDir, 1)));

                col.rgb = lerp(pbr,toon,_Toon);                                         
                
                fixed4 refl = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, viewDir, 0) + saturate(fixed4(ShadeSH9(half4(-normalDir,1)),1));
                //col.rgb += pow(smoothstep(0,1,1-saturate(depth/_Opacity)),_Decay) * lerp(refl.rgb,_SSSColor,_SSSBlend);
                col.rgb += pow(1-saturate(depth/_Opacity),_Decay) * lerp(refl.rgb,_SSSColor,_SSSBlend) * mlambert;
                // apply fog
                UNITY_APPLY_FOG(i.fogCoord, col);

				return col;
            }
            ENDCG
        }
        
		Pass
		{
			Tags { "LightMode"="ForwardAdd"}
			ZWrite On
			Cull Back
			ZTest LEqual
			Blend One One
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			// make fog work
           #pragma multi_compile_fwdadd
			#pragma multi_compile_fog
			
			#include "UnityCG.cginc"
			#include "Lighting.cginc"
			#include "AutoLight.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
				float3 normal : NORMAL;
				float4 tangent : TANGENT;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				UNITY_FOG_COORDS(1)
                SHADOW_COORDS(2) // put shadows data into TEXCOORD1
				float4 pos : SV_POSITION;
				float3 normal : NORMAL;
				float3 tangent : TANGENT;
				float3 bitTangent : Bit_Tangent;
				float4 grabPos : Grab_Pos;
				float3 wPos : World_Pos;
			};

            sampler2D _BackDepthTexture;

			sampler2D _MainTex;
			float4 _MainTex_ST;

			fixed4 _Color;

			sampler2D _BumpMap;
			float _BumpScale;

			float _HalfLambert;

			float _Metalic;
			float _Roughness;

			float _PointLightTransparent;
			float _Balance;
			float _PointLightPower;

			fixed4 _SSSColor;
			float _SSSBlend;

			float _Opacity;
			float _Decay;

			float _PBR;
			
			v2f vert (appdata v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				o.normal = normalize(UnityObjectToWorldNormal(v.normal));
				o.tangent = normalize(UnityObjectToWorldDir(v.tangent));
				o.bitTangent = normalize(cross(o.normal, o.tangent) * v.tangent.w);
				o.grabPos = ComputeGrabScreenPos(o.pos);
				o.wPos = mul(UNITY_MATRIX_M,v.vertex).xyz;
				UNITY_TRANSFER_FOG(o,o.pos);
                TRANSFER_SHADOW(o)
				return o;
			}
			
			fixed4 frag (v2f i) : SV_Target
			{
				float frontDepth = distance(i.wPos,_WorldSpaceCameraPos);
				float backDepth = tex2Dproj(_BackDepthTexture,i.grabPos);
				float depth = backDepth - frontDepth;

				float3 viewDir = normalize(i.wPos - _WorldSpaceCameraPos);
				float3x3 tangentTransform = float3x3(i.tangent,i.bitTangent,i.normal);
				float3 bump = lerp( float3(0,0,1), tex2D(_BumpMap, i.uv), _BumpScale); //sample Bumpmap
				float3 normalDir = normalize(mul( bump, tangentTransform));

				float3 lightDir = -normalize(_WorldSpaceLightPos0.xyz - i.wPos.xyz*_WorldSpaceLightPos0.w);

				float dotNV = max(0,dot(normalDir,viewDir));
				float dotNL = max(0,dot(normalDir,lightDir));
				float dotVL = max(0,dot(viewDir,-lightDir));

				float lambert = saturate(lerp(dotNL,dotNL * 2.0 - 1.0, _HalfLambert));
                UNITY_LIGHT_ATTENUATION(shadowAtt, i, i.wPos.xyz);
				// sample the texture
				fixed4 col = tex2D(_MainTex, i.uv) * _Color;
                clip(col.a-0.5);
				// fixed3 pbr = calcPBRCol( col,
				// 					  _Metalic*0, _Roughness,
				// 					  dotNV, viewDir, normalDir, lightDir,
				// 					  1-lambert, _LightColor0.rgb*shadowAtt*shadowAtt);

				fixed3 pbr;
				{
					float roughness = _Roughness * 0.75;

					fixed3 light = pow( dotNL, pow(1000,roughness*roughness)) * fixed4(_LightColor0.rgb*shadowAtt*shadowAtt,1);
					pbr =  light;
				}

				col.rgb = lerp(col,pbr,1);

				float lighter = pow(1-saturate(length(_WorldSpaceLightPos0.xyz - i.wPos.xyz)/_Opacity),_Decay);
				fixed3 lightPower = _LightColor0.rgb*shadowAtt*shadowAtt;
				fixed3 lookLight = saturate(pow(dotVL,_PointLightTransparent)) * _LightColor0.rgb * shadowAtt;
				return fixed4(pbr*_PointLightPower + lerp(lightPower,lookLight,_Balance) * lighter,1);

			}
			ENDCG
		}

        Pass
        {
            Name "ShadowCast"
            Tags {"LightMode" = "ShadowCaster"}
            Cull Back
            ZTest Less

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_shadowcaster
            #include "UnityCG.cginc"

            struct v2f {
                    V2F_SHADOW_CASTER;
            };

            v2f vert(appdata_base v)
            {
                    v2f o;
                    TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
                    return o;
            }

            float4 frag(v2f i) : SV_Target
            {
                    SHADOW_CASTER_FRAGMENT(i)
            }
            ENDCG
        }

        CGINCLUDE
            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            #include "AutoLight.cginc"
            #define LIMIT_ZERO 0.0001
            inline fixed3 calcPBRCol(fixed3 mainCol,
                                    float metalic,
                                    float roughness,
                                    float dotNV, float3 viewDir, float3 normalDir, float3 lightDir,
                                    float lambert, fixed3 lightColor)
            {
                fixed3 col = mainCol;
                //GI
                float3 reflDir = reflect(-viewDir, normalDir);
                float fresnel = roughness + (1.0h - roughness) * pow(1.0 - dotNV, 5);
                fixed3 refColor = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, reflDir, 5*(1-roughness)) * fresnel; //sample refrection
                fixed3 specular = pow( max(0,dot(reflect(-lightDir,normalDir),viewDir)), pow(1000,roughness*roughness)) * fixed4(lightColor,1) * roughness;
                fixed3 light = specular + refColor;
                light = lerp(light,light*col,length(col.rgb));
                fixed3 enviroment = saturate(fixed4(ShadeSH9(half4(normalDir,1)),1)) * col; //sample emviroment color
                fixed3 diffuse = lambert * fixed4(lightColor,1) * col;
                fixed3 base = diffuse + enviroment * metalic;
                col =  lerp(base, light*fixed4(lightColor,1), 0.5);
                return col;
            }

            float _Shade1Power0, _Shade1Power1;
            
            inline fixed3 calcToonCol(fixed3 mainCol,
                                    float shadeShift0, float shadeToony0, fixed4 shadeColor0,
                                    float shadeShift1, float shadeToony1, fixed4 shadeColor1,
                                    float lambert, fixed3 lightColor, fixed3 indirectLighting)
            {
                // Threshold
                float maxIntensityThreshold0 = lerp(1, shadeShift0, shadeToony0);
                float minIntensityThreshold0 = shadeShift0;
                float lightIntensity0 = pow(saturate((lambert - minIntensityThreshold0) / max(LIMIT_ZERO, (maxIntensityThreshold0 - minIntensityThreshold0))),_Shade1Power0);
                float maxIntensityThreshold1 = shadeShift1;
                float minIntensityThreshold1 = lerp(shadeShift1, -1, 1-shadeToony1);
                float lightIntensity1 = pow(saturate((lambert - minIntensityThreshold1) / max(LIMIT_ZERO, (maxIntensityThreshold1 - minIntensityThreshold1))),_Shade1Power1);

                // Albedo color
                fixed3 col = lerp(lerp(shadeColor1, shadeColor0, lightIntensity1), mainCol, lightIntensity0);

                //lighting
                col.rgb *= lightColor;

                // GI
                col.rgb += indirectLighting * mainCol;
                
                col = min(col,mainCol); //白飛び防止
                
                return col;
            }
        ENDCG
	}
}
