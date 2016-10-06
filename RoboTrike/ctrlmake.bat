asm86 serial.asm m1 ep db
asm86 buttons.asm m1 ep db
asm86 chipslct.asm m1 ep db
asm86 converts.asm m1 ep db
asm86 displays.asm m1 ep db
asm86 queues.asm m1 ep db
asm86 irqvects.asm m1 ep db
asm86 int2.asm m1 ep db
asm86 ctrltmr0.asm m1 ep db
asm86 events.asm m1 ep db
asm86 contmain.asm m1 ep db
asm86 contbrd.asm m1 ep db
link86 serial.obj, buttons.obj, displays.obj, converts.obj, queues.obj, serial.obj TO templnk1.lnk
link86 irqvects.obj, int2.obj, ctrltmr0.obj, events.obj, contbrd.obj, contmain.obj TO templnk2.lnk
link86 templnk1.lnk, templnk2.lnk TO ctrlmain.lnk
loc86 ctrlmain.lnk AD(SM(CODE(4000H), DATA(400H), STACK(7000H))) NOIC