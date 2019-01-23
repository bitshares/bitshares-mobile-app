//
//  CompileTimeMacro.h
//  oplayer
//
//  Created by Aonichan on 16/1/15.
//
//

#ifndef __CompileTimeMacro_h__
#define __CompileTimeMacro_h__

/**
 *  编译时MD5
 */
#define __CTM_MD5(value)    value

/**
 *  编译时：'=' + 异或+Base64
 */
#define __CTM_XORB64(value) value

#endif /* __CompileTimeMacro_h__ */
