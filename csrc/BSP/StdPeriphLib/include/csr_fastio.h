

#ifndef CSR_FASTIO_H
#define CSR_FASTIO_H
#include <stdint.h>

// #define CSRFIO_WDAT 0xB03
// #define CSRFIO_WMSK 0xB04
// #define CSRFIO_DDAT 0xB05
// #define CSRFIO_DMSK 0xB06
// #define CSRFIO_RDAT 0xB07

static inline void CSRFIOWrite(uint32_t DATA)
{
    asm volatile(
        "csrw 0xB03, %[src] ;"
        : [src] "=r"(DATA));
}
static inline uint32_t CSRFIORaS(uint32_t OPCODE) //READ AND SET
{
    register uint32_t temp; 
    asm volatile(
        "csrrs %[dest] , 0xB03, %[src]"
        : [dest] "=r"(temp)
        : [src] "r"(OPCODE));
    return temp;
}

static inline uint32_t CSRFIORaC(uint32_t OPCODE) //READ AND CLEAR
{
    register uint32_t temp; 
    asm volatile(
        "csrrc %[dest] , 0xB03, %[src]"
        : [dest] "=r"(temp)
        : [src] "r"(OPCODE));
    return temp;
}

static inline uint32_t CSRFIOGetWriteVal()
{
    uint32_t temp;
    asm volatile(
        "csrr %[dest] , 0xB03"
        : [dest] "=r"(temp));
    return temp;
}
static inline uint32_t CSRFIOWarWriteVal(uint32_t DATA) //Write And Read
{
    uint32_t temp;
    asm volatile(
        "csrrw %[dest] , 0xB03, %[src]"
        : [dest] "=r"(temp)
        : [src] "r"(DATA));
    return temp;
}

static inline void CSRFIOWriteMask(uint32_t DATA)
{
    asm volatile(
        "csrw 0xB04, %[src] ;"
        : [src] "=r"(DATA));
}
static inline uint32_t CSRFIOGetWriteMask()
{
    uint32_t temp;
    asm volatile(
        "csrr %[dest] , 0xB04"
        : [dest] "=r"(temp));
    return temp;
}
static inline uint32_t CSRFIOWarWriteMask(uint32_t DATA) //Write And Read
{
    uint32_t temp;
    asm volatile(
        "csrrw %[dest] , 0xB04, %[src]"
        : [dest] "=r"(temp)
        : [src] "r"(DATA));
    return temp;
}

static inline void CSRFIOWriteDir(uint32_t DATA)
{
    asm volatile(
        "csrw 0xB05, %[src] ;"
        : [src] "=r"(DATA));
}
static inline uint32_t CSRFIOGetDir()
{
    uint32_t temp;
    asm volatile(
        "csrr %[dest] , 0xB05"
        : [dest] "=r"(temp));
    return temp;
}

static inline uint32_t CSRFIODirRaS(uint32_t OPCODE) //READ AND SET
{
    register uint32_t temp; 
    asm volatile(
        "csrrs %[dest] , 0xB05, %[src]"
        : [dest] "=r"(temp)
        : [src] "r"(OPCODE));
    return temp;
}

static inline uint32_t CSRFIODirRaC(uint32_t OPCODE) //READ AND CLEAR
{
    register uint32_t temp; 
    asm volatile(
        "csrrc %[dest] , 0xB05, %[src]"
        : [dest] "=r"(temp)
        : [src] "r"(OPCODE));
    return temp;
}

static inline uint32_t CSRFIOWarDir(uint32_t DATA) //Write And Read
{
    uint32_t temp;
    asm volatile(
        "csrrw %[dest] , 0xB05, %[src]"
        : [dest] "=r"(temp)
        : [src] "r"(DATA));
    return temp;
}

static inline void CSRFIOWriteDirMask(uint32_t DATA)
{
    asm volatile(
        "csrw 0xB06, %[src] ;"
        : [src] "=r"(DATA));
}
static inline uint32_t CSRFIOGetDirMask()
{
    uint32_t temp;
    asm volatile(
        "csrr %[dest] , 0xB06"
        : [dest] "=r"(temp));
    return temp;
}
static inline uint32_t CSRFIOWarDirMask(uint32_t DATA) //Write And Read
{
    uint32_t temp;
    asm volatile(
        "csrrw %[dest] , 0xB06, %[src]"
        : [dest] "=r"(temp)
        : [src] "r"(DATA));
    return temp;
}

static inline uint32_t CSRFIORead()
{
  uint32_t temp;
    asm volatile(
        "csrr %[dest] , 0xB07"
        :[dest]"=r"(temp)
        );
  return temp;
}


#endif /* CSR_FASTIO_H */
