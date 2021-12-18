# CPU

## 通过point 1
1.添加ex、mem数据相关：ex_id,mem_id连线

2.添加subu、jal、slt、jr、addu、bne指令

3.添加wb数据相关

4.添加or、xor、sll、lw指令


## 通过point15

1.在MEM段插入气泡解决了lw中定向不能解决的数据相关

2.添加了sw、sltu、slti、sltiu、j、add、addi、and、andi指令

## 通过point43

添加了nor、xori、sllv、sra、srl、srav、srlv、bgez、bgtz、blez、bltz、bltzal、bgezal、jalr指令

## 通过point58

1.添加了特殊寄存器：lo寄存器、hi寄存器

2.添加了乘除法器

3.通过定向和在ex段插入气泡解决了数据相关

4.添加了div divu mult multu mfhi mfio mthi mtio指令

## 通过point64

添加了lb lbu lh lhu sh sb 指令

12.15 更新WXX下分支所有文件
