
main:
lui x2, -78
auipc x3, 20
lui x4, 20
jal x1, Jal_test           #call test
Loop:
beq x0, x0, Loop

Jal_test:
lui x5, 35
add x6, x5, x4              
add x6, x6, x5             # x6 = 90 is correct
jalr x0, x1, 0             #return