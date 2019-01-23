//
//  12306crypt.c
//  oplayer
//
//  Created by Aonichan on 16/1/15.
//
//

#include "12306crypt.h"
#include "base64.h"

#pragma mark- realm
int realm_x_transition(char buff[800], const char* key, int fillidx, int num1, int num2)
{
    size_t keylen = strlen(key);
    size_t r6 = num1 % keylen;
    size_t r0 = num2 % keylen;
    size_t r3 = r6;
    if (r0 < r6){
        r3 = r0;
        r0 = r6;
    }
    if (r0 < keylen){
        size_t r5 = r0 - r3 + 0x1;
        memcpy(&buff[fillidx], &key[r3], r5);
        fillidx += r5;
    }
    return fillidx;
}

char* realm_match_to_s(int idx, const char* str) {
    const char* newstr = str + idx;
    //  查找 'S' 在字符串的位置
    char* r0 = strchr(newstr, 'S');
    size_t len;
    if (r0 != 0x0) {
        len = r0 - newstr;
    }
    else {
        len = 0x0;
    }
    return strndup(newstr, len);
}

#pragma mark- encode
unsigned char * sub_219D00_encode_aes_process(unsigned char* a1, unsigned char* a2, int a3, signed int a4)
{
    signed int v4; // r0@1
    unsigned char v5; // r6@2
    signed int v6; // kr00_4@2
    int v7; // r4@2
    int v8; // r5@6
    unsigned char *v9; // r1@8
    int v10; // r6@10
    int v11; // r0@10
    char *v12; // lr@11
    int v13; // r10@11
    int v14; // r6@12
    char *v15; // r0@12
    int v16; // r3@13
    char *v17; // r5@14
    int v18; // lr@18
    int v19; // r9@18
    int v20; // r0@19
    int v21; // r3@20
    signed int v22; // r10@20
    int v23; // r11@20
    char v24; // r5@20
    char *v25; // r3@20
    char v26; // r6@20
    unsigned char v27; // r3@20
    char v28; // r6@21
    int v29; // r2@21
    int v30; // r2@22
    int v31; // r1@25
    int v32; // r4@26
    int v33; // r0@26
    int v34; // r6@27
    int v35; // r3@27
    char v36; // r3@28
    signed int v37; // r0@32
//    char *result; // r0@34
    unsigned char* v39; // [sp+8h] [bp-98h]@1
    int v40; // [sp+Ch] [bp-94h]@8
    int v41; // [sp+10h] [bp-90h]@1
    int v42; // [sp+14h] [bp-8Ch]@11
    int v43; // [sp+18h] [bp-88h]@11
    int v44; // [sp+1Ch] [bp-84h]@11
    int v45; // [sp+1Ch] [bp-84h]@19
    char v46[4]={0,}; // [sp+20h] [bp-80h]@20
//    char v47; // [sp+21h] [bp-7Fh]@20
    char v48; // [sp+22h] [bp-7Eh]@20
    char v49; // [sp+23h] [bp-7Dh]@20
    char v50[16]={0,}; // [sp+24h] [bp-7Ch]@30
    char v51[64]={0,}; // [sp+34h] [bp-6Ch]@11
    char v52[16]={0,}; // [sp+74h] [bp-2Ch]@2
    //    unsigned char *v53; // [sp+84h] [bp-1Ch]@1
    
    v41 = a3;
    v39 = a1;
    //    v53 = __stack_chk_guard;
    v4 = 0;
    do
    {
        v5 = *(unsigned char *)(a2 + v4);
        v6 = v4;
        v7 = v4 - ((v4 + ((unsigned int)(v4 >> 31) >> 30)) & 0x3FFFFFFC);
        ++v4;
        *(&v52[4 * v7] + v6 / 4) = v5;
    }
    while ( v4 != 16 );
    if ( !a4 )
        a4 = 10;
    if ( a4 >= 1 )
    {
        v8 = 8;
        if ( 9 != a4 && (unsigned int)-a4 >= 0xFFFFFFF7 )
            v8 = a4 - 1;
        v9 = table_encode_01_n_00300ae6;
        v40 = v8;
        if ( a3 )
            v9 = table_encode_01_s_002caae6;
        v10 = 0;
        v11 = 0;
        do
        {
            v12 = v51;
            v42 = v11;
            v13 = 0;
            v43 = v10;
            v44 = v11 << 14;
            do
            {
                v14 = 0;
                v15 = v12;
                do
                {
                    v16 = (v44 + (v13 << 10) + ((v13 + v14) % 4 << 12)) | 4 * (unsigned char)*(&v52[4 * v13] + (v13 + v14) % 4);
                    if ( a3 )
                        v17 = (char *)table_encode_02_s_00282ae6;
                    else
                        v17 = (char *)table_encode_02_n_002a6ae6;
                    ++v14;
                    *(unsigned int *)v15 = *(unsigned int *)&v17[v16];
                    v15 += 4;
                }
                while ( v14 != 4 );
                ++v13;
                v12 += 16;
            }
            while ( v13 != 4 );
            v18 = v43;
            v19 = 0;
            do
            {
                v20 = 0;
                v45 = v18;
                do
                {
                    v21 = v19 + 4 * v20;
                    v22 = 1;
                    v23 = v18;
                    v24 = v51[v21];
                    v25 = &v51[v21];
                    v46[0] = v24;
                    v46[1] = v25[16];
                    v46[2] = v25[32];
                    v46[3] = v25[48];
                    v48 = v26;
                    v49 = (char)v25;
                    v27 = v24 & 0xF0;
                    do
                    {
                        v28 = v46[v22++];
                        v27 = 16 * v9[(v28 & 0xF0) | (v27 >> 4) | (v23 + 256)];
                        v29 = (v24 & 0xF) | v23;
                        v23 += 512;
                        v24 = v9[v29 | (unsigned char)(16 * v28)];
                    }
                    while ( v22 != 4 );
                    v30 = v20++ + 4 * v19;
                    v18 += 6144;
                    v52[v30] = v27 | (v24 & 0xF);
                }
                while ( v20 != 4 );
                ++v19;
                v18 = v45 + 1536;
            }
            while ( v19 != 4 );
            v11 = v42 + 1;
            a3 = v41;
            v10 = v43 + 24576;
        }
        while ( v42 != v40 );
    }
    v31 = 0;
    do
    {
        v32 = 0;
        v33 = 0;
        do
        {
            v34 = v32 + ((v31 + v33) % 4 << 10);
            v32 += 256;
            v35 = (unsigned char)*(&v52[4 * v33] + (v31 + v33) % 4) | v34;
            if ( a3 )
                v36 = table_encode_03_s_00336ae6[v35];
            else
                v36 = table_encode_03_n_00337ae6[v35];
            *(&v50[4 * v33++] + v31) = v36;
        }
        while ( v33 != 4 );
        ++v31;
    }
    while ( v31 != 4 );
    v37 = 0;
    do
    {
        *(unsigned char *)(v39 + v37) = *(&v50[4 * (v37 - ((v37 + ((unsigned int)(v37 >> 31) >> 30)) & 0x3FFFFFFC))] + v37 / 4);
        ++v37;
    }
    while ( v37 != 16 );
    //    result = (char *)((unsigned char *)__stack_chk_guard - v53);
    //    if ( __stack_chk_guard != v53 )
    //        __stack_chk_fail(result);
    return v39;
}

#pragma mark- deocde
char * sub_21A05C_decode_aes_process(char* a1, char* a2, int a3, signed int a4)
{
    signed int v4; // r0@1
    char v5; // r4@2
    signed int v6; // kr00_4@2
    int v7; // r6@2
    //    int v8; // r6@6
    char *v9; // r1@6
    int v10; // r3@8
    int v11; // r0@9
    char *v12; // r3@9
    int v13; // lr@9
    int v14; // r9@10
    int v15; // r5@12
    char *v16; // r0@12
    int v17; // r4@13
    char *v18; // r3@14
    int v19; // r10@18
    int v20; // r12@18
    int v21; // r0@19
    int v22; // r2@20
    signed int v23; // r9@20
    char v24; // r11@20
    char *v25; // r2@20
    unsigned int v26; // r3@20
    int v27; // r2@20
    char v28; // r4@21
    int v29; // r3@21
    char* v30; // r5@21
    int v31; // r2@22
    int v32; // r8@26
    signed int v33; // r1@26
    char *v34; // r0@27
    int v35; // r5@27
    signed int v36; // r4@27
    char *v37; // r3@27
    signed int v38; // r2@28
    int v39; // r2@30
    int v40; // r6@30
    int v41; // r2@30
    char v42; // r2@31
    signed int v43; // r0@35
//    char *result; // r0@37
    char* v45; // [sp+8h] [bp-9Ch]@1
    signed int v46; // [sp+Ch] [bp-98h]@5
    int v47; // [sp+10h] [bp-94h]@1
    signed int v48; // [sp+14h] [bp-90h]@9
    signed int v49; // [sp+18h] [bp-8Ch]@8
    int v50; // [sp+1Ch] [bp-88h]@9
    int v51; // [sp+1Ch] [bp-88h]@19
    char *v52; // [sp+20h] [bp-84h]@10
    char v53[4]={0,}; // [sp+24h] [bp-80h]@20
//    char v54; // [sp+25h] [bp-7Fh]@20
//    char v55; // [sp+26h] [bp-7Eh]@20
//    char v56; // [sp+27h] [bp-7Dh]@20
    char v57[16]={0,}; // [sp+28h] [bp-7Ch]@27
    char v58[64]={0,}; // [sp+38h] [bp-6Ch]@9
    char v59[16]={0,}; // [sp+78h] [bp-2Ch]@2
    //    unsigned char *v60; // [sp+88h] [bp-1Ch]@1
    
    v47 = a3;
    v45 = a1;
    //    v60 = __stack_chk_guard;
    v4 = 0;
    do
    {
        v5 = *(unsigned char *)(a2 + v4);
        v6 = v4;
        v7 = v4 - ((v4 + ((unsigned int)(v4 >> 31) >> 30)) & 0x3FFFFFFC);
        ++v4;
        *(&v59[4 * v7] + v6 / 4) = v5;
    }
    while ( v4 != 16 );
//    printbufferd(v59, 16);
    //    printbuffer(v58, 64);
    if ( !a4 )
        a4 = 1;
    v46 = a4;
    if ( a4 <= 10 )
    {
        //        LOWORD(v8) = 0x4000;
        v9 = (char *)table_decode_01_n_003b6ae6;
        if ( a3 )
            v9 = (char *)table_decode_01_s_00380ae6;
        v10 = 10;
        //        HIWORD(v8) = -1;
        v49 = 245760;
        do
        {
//            printf("round:%d\n", v10);
            v11 = v10 << 14;
            v48 = v10;
            v12 = v58;
            v13 = 0;
            v50 = v11;
            do
            {
                v14 = v13;
                v52 = v12;
                if ( v13 )
                    v14 = 4 - v13;
                v15 = 0;
                v16 = v12;
                do
                {
                    v17 = ((v50 + (v13 << 10) + ((v14 + v15) % 4 << 12)) | 4 * (unsigned char)*(&v59[4 * v13] + (v14 + v15) % 4))
                    - 0x8000;
                    if ( a3 )
                        v18 = (char *)table_decode_02_s_00338ae6;
                    else
                        v18 = (char *)table_decode_02_n_0035cae6;
                    ++v15;
                    *(unsigned int *)v16 = *(unsigned int *)&v18[v17];
                    v16 += 4;
                    
                }
                while ( v15 != 4 );
                ++v13;
                v12 = v52 + 16;
            }
            while ( v13 != 4 );
//            printf("keys:\n");
//            printbufferd(v58, 64);
            v19 = v49;
            v20 = 0;
            do
            {
                v51 = v19;
                v21 = 0;
                do
                {
                    v22 = v20 + 4 * v21;
                    v23 = 1;
                    v24 = v58[v22]; //  v58:key
                    v25 = &v58[v22];
                    v53[0] = v24;
                    v53[1] = v25[16];
                    v53[2] = v25[32];
                    v26 = v24 & 0xF0;
                    v53[3] = v25[48];
                    v27 = v19;
                    do
                    {
                        //                        v37[1] = v17[16];
                        //                        v37[2] = v17[32];
                        //                        v37[3] = v17[48];
                        v28 = v53[v23];
                        v29 = (v26 >> 4) | (v27 + 256) | (unsigned char)(v28 & 0xF0);
                        v30 = (char*)&v9[(v24 & 0xF) | v27 | (unsigned char)(16 * v28)];
                        ++v23;
                        v27 += 512;
                        v24 = *(char *)(v30 - 0xc000);
                        v26 = 16 * *(&v9[v29] - 0xc000);
                    }
                    while ( v23 != 4 );
                    v31 = 4 * v20 + v21++;
                    v19 += 6144;
                    v59[v31] = v26 | (v24 & 0xF);
                }
                while ( v21 != 4 );
                ++v20;
                v19 = v51 + 1536;
            }
            while ( v20 != 4 );
//            printf("state:\n");
//            printbufferd(v59, 16);
            a3 = v47;
            if ( v48 < 3 )
                break;
            v49 -= 24576;
            v10 = v48 - 1;
        }
        while ( v48 > v46 );
    }
    v32 = a3;
    v33 = 0;
    do
    {
        v34 = v59;
        v35 = 0;
        v36 = 4;
        v37 = v57;
        do
        {
            v38 = v33;
            if ( v35 )
                v38 = v33 + v36;
            v39 = v38 % 4;
            v40 = (unsigned char)v34[v39];
            v34 += 4;
            v41 = (v35 + (v39 << 10)) | v40;
            v35 += 256;
            if ( v32 )
                v42 = table_decode_03_s_003ecae6[v41];
            else
                v42 = table_decode_03_n_003edae6[v41];
            --v36;
            v37[v33] = v42;
            v37 += 4;
        }
        while ( v36 );
        ++v33;
    }
    while ( v33 != 4 );
    v43 = 0;
    do
    {
        *(unsigned char *)(v45 + v43) = *(&v57[4 * (v43 - ((v43 + ((unsigned int)(v43 >> 31) >> 30)) & 0x3FFFFFFC))] + v43 / 4);
        ++v43;
    }
    while ( v43 != 16 );
    return v45;
}


#pragma mark- api

//  12306 mobile api: encrypt message
char* fencrypt(const char* plaintext, int len, int typeS)
{
    if (!plaintext){
        return 0;
    }
    
    //  补齐
    const char* src = plaintext;
    unsigned int len2 = (len + 16) & 0xFFFFFFF0;
    char* v7 = malloc(len2);
    memset(v7, 0, len2);
    strncpy(v7, src, len);
    if ( len2 > len )
        memset((char *)v7 + len, len2 - len, len2 - len);
    char* v8 = malloc(len2 | 1);
    memset(v8, 0, len2 | 1);
    
    //  加密
    int v9 = 0;
    do
    {
        char* v10 = v7 + v9;
        int v11 = 0;
        do
        {
            unsigned char v12 = *(unsigned char *)(v10 + v11);
            if ( v9 >= 1 )
                v12 ^= *((char *)v8 + v11 + v9 - 16);
            *(unsigned char *)(v10 + v11++) = v12;
        }
        while ( v11 != 16 );
        sub_219D00_encode_aes_process((unsigned char *)v8 + v9, (unsigned char *)v10, typeS, 10);
        v9 += 16;
    }
    while ( v9 < len2 );
    free(v7);
    
    //  base64 编码
    int base64_len = Base64encode_len(len2);
    char* outputbuffer = malloc(1 + base64_len + 1);
    //  头部添加S或F、末尾设置0。
    outputbuffer[0] = typeS ? 'S' : 'F';
    outputbuffer[1 + base64_len] = 0;
    //  编码
    Base64encode(&outputbuffer[1], v8, len2);
    return outputbuffer;
}

//  12306 mobile api: decrypt message
char* fdecrypt(const char* cihpertext, int cihpertext_len)
{
    if (!cihpertext || cihpertext_len < 2){
        return 0;
    }
    int is_s_prefix = *cihpertext == 'S' ? 1 : 0;
    
    //  base64 解码
    int len = Base64decode_len(&cihpertext[1]);

    char* buff01 = malloc(len + 1);
    buff01[len] = 0;
    len = Base64decode(buff01, &cihpertext[1]);
    if (len == 0 || (len % 16) != 0){
        return 0;
    }

    const char* decodebase64 = buff01;
    
    //  解密
    char* v14 = malloc(len + 1);
    int v8 = 0;
    memset(v14, 0, len + 1);
    do
    {
        char* v9 = (char*)v14 + v8;
        sub_21A05C_decode_aes_process((char*)v14 + v8, (char*)&decodebase64[v8], is_s_prefix, 1);
        int v10 = 0;
        do
        {
            unsigned char v11 = *(unsigned char *)(v9 + v10);
            if ( v8 >= 1 )
                v11 ^= *(&decodebase64[v10 - 16] + v8);
            *(unsigned char *)(v9 + v10++) = v11;
        }
        while ( v10 != 16 );
        v8 += 16;
    }
    while ( v8 < len );
    
    //  去掉补齐的数据
    char v12 = *((char *)v14 + len - 1);
    int final_len = len;
    if ( v12 <= 16 )
    {
        *((unsigned char *)v14 + len - v12) = 0;
        final_len = len - v12;
    }
    
    //  返回
    free(buff01);
    return v14;
}

//  12306 mobile api: calc realm value for worklight
char* frealm(const char* str, const char* key1, const char* key2)
{
    size_t str_len = strlen(str);
    if (str_len <= 0){
        return 0;
    }
    
    char buff[800] = {0,};
    char tmp[4] = {0,};
    
    int fillidx = 0;
    int scan_idx = 0;
    int save_idx;
    
    while (1)
    {
        do
        {
            tmp[0] = str[scan_idx];
            tmp[1] = str[scan_idx + 1];
            tmp[2] = str[scan_idx + 2];
            int num1 = atoi(tmp);
            
            tmp[0] = str[scan_idx + 3];
            tmp[1] = str[scan_idx + 4];
            tmp[2] = str[scan_idx + 5];
            int num2 = atoi(tmp);
            
            save_idx = scan_idx + 0x6;
            char ch = str[save_idx];
            if (ch < 'N'){
                if (ch != 'C'){
                    break;
                }
                //  c change
                fillidx = realm_x_transition(buff, key2, fillidx, num1, num2);
            }
            else if (ch != 'X'){
                if (ch != 'N'){
                    break;
                }
                //  n change
                fillidx = realm_x_transition(buff, key1, fillidx, num1, num2);
            }
            else{
                //  x change
                scan_idx += 0x7;
                char* r0 = realm_match_to_s(scan_idx, str);
                size_t len_r0 = strlen(r0);
                if (fillidx >= 0x1){
                    for (int i = 0; i < fillidx; ++i) {
                        buff[i] = r0[i % len_r0] ^ buff[i];
                    }
                }
                free(r0);
                save_idx = scan_idx + (int)len_r0;
            }
        } while (0);
        //  变换结束
        scan_idx = save_idx + 1;
        if (scan_idx >= str_len){
            break;
        }
    }
    
    //  base64 编码
    int base64_len = Base64encode_len(fillidx);
    char* outputbuffer = malloc(1 + base64_len + 1);
    //  头部添加i、末尾设置0。
    outputbuffer[0] = 'i';
    outputbuffer[1 + base64_len] = 0;
    //  编码
    Base64encode(&outputbuffer[1], buff, fillidx);
    return outputbuffer;
}

void ffree(void* ptr)
{
    if (ptr){
        free(ptr);
    }
}