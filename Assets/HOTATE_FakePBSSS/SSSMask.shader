Shader "HOTATE/SSS/Mask"
{
	Properties
    {
		[HideInInspector] _Stencil ("Stencil", Float) = 750
	}
	SubShader
	{
		Tags{"Queue"="Geometry+50"}
        Stencil
        {
            Ref [_Stencil]
            Comp Always
            Pass Replace
        }
        Pass
        {
            ColorMask 0
            ZWrite On
            ZTest LEqual
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                return 0;
            }
            ENDCG
        }
    }
}
