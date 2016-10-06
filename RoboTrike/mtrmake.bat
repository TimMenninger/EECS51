asm86 chipslct.asm m1 ep db
asm86 displays.asm m1 ep db
asm86 converts.asm m1 ep db
asm86 events.asm m1 ep db
asm86 int2.asm m1 ep db
asm86 irqvects.asm m1 ep db
asm86 motbrd.asm m1 ep db
asm86 motmain.asm m1 ep db
asm86 motors.asm m1 ep db
asm86 mtrtmr0.asm m1 ep db
asm86 parsefsm.asm m1 ep db
asm86 queues.asm m1 ep db
asm86 serial.asm m1 ep db
asm86 sinevals.asm m1 ep db
link86 chipslct.obj, irqvects.obj, int2.obj, mtrtmr0.obj, converts.obj, displays.obj, queues.obj TO templnk1.lnk
link86 sinevals.obj, motors.obj, serial.obj, parsefsm.obj, events.obj, motbrd.obj, motmain.obj TO templnk2.lnk
link86 templnk1.lnk, templnk2.lnk TO mtrmain.lnk
loc86 mtrmain.lnk AD(SM(CODE(4000H), DATA(400H), STACK(7000H))) NOIC