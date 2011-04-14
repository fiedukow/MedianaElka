.data
#filename:	.asciiz "qt.bmp"
#new_filename:	.asciiz "output.bmp"
#.align 2
filename:	.space 64
new_filename:	.space 64
#.align 2
thanks:		.asciiz "\nProgram zakonczyl dzialanie, wynik dzialania zapisano w pliku "
question_s: 	.asciiz "Nazwa pliku do przerobienia (max. 64 znaki) > "
question_t:	.asciiz "Nazwa pliku do zapisania wyniku (max. 64 znaki; UPRAWNIENIA ZAPISU!) > "
newline: 	.asciiz "\n"
processing: 	.asciiz "Processing.."
dot:		.asciiz "."

.align 2
fl: .space 4 # current 1st line pointer
sl: .space 4 # current 2nd line pointer
tl: .space 4 # current 3rd line pointer
pl: .space 4 # current proccesed line result

.text
main:	

# Register once set keep their value till the end:
# s1 - file descriptor of source
# s2 - width (same for both files) 
# s3 - height (same for both files) 
# s5 - file descriptor of result
# s6 - bytes in one line with complement
	
##################################################################################		
## ASKING USER FOR FILENAMES AND PROGRESSING IT
##################################################################################

	## SYSCALL (print first question)
	li $v0,4 # print_string service
	la $a0,question_s # show place where the string is
	syscall # printf(question_s)
	
	## SYSCALL (take filename of file to process)
	li $v0, 8 # read_string service
	la $a0, filename #show place for source filename (global variable)
	li $a1, 64 # max. filename size is 64
	syscall # scanf(source_filename, 64)

	## SYSCALL (print second question)				
	li $v0,4 # print_string service
	la $a0,question_t # show place where the string is
	syscall # printf(question_t)
	
	## SYSCALL (take filename of file for output)
	li $v0, 8 # read-string service
	la $a0, new_filename #show place for target filename (global variable)
	li $a1, 64 # max. filename size is 64
	syscall # scanf(target_filename, 64)
	
	#for(i=0;l[i]!='\n';++i);
	#l[i]='\0';
	# Change first \n to \0 in loaded filenames
	
	# changing in source_file
	li $t0, 0
	la $t1, filename
	no_nl:
	 	addu $t2,$t1,$t0
	 	lb $t3,0($t2)
	 	bne $t3,10,skip_nl
	 	sb $0, 0($t2)
	 	j no_nl_end
	 	skip_nl:
	 	addiu $t0,$t0,1
		j no_nl
	no_nl_end:

	
	# changing in target_file	
	li $t0, 0
	la $t1, new_filename
	no_nln:
	 	addu $t2,$t1,$t0
	 	lb $t3,0($t2)
	 	bne $t3,10,skip_nln
	 	sb $0, 0($t2)
	 	j no_nl_endn
	 	skip_nln:
	 	addiu $t0,$t0,1
		j no_nln
	no_nl_endn:
	
	# Filenames are now valid (without \n in the end).
	# All register FREE


##################################################################################		
## OPENING FILES WITH AND FOR DATA
##################################################################################

	## SYSCALL (open file for reading, $s1 is file descriptor)
	li $v0, 13 # open-file service
	la $a0, filename # 0($s0) # set filename to read
	li $a1, 0 # read-only flag
	li $a2, 0 # ignore mode
	syscall # open file, $v0 gets file-descriptior	
	move $s1, $v0 # let s1 be file descriptor for old file
	
	## SYSCALL (open file for writing (for save the result of program))
	li $v0, 13 # open-file service
	la $a0, new_filename # show file to write to
	li $a1, 1 # write flag
	li $a2, 0 # ignore mode
	syscall # open result file for writing, $v0 gets descriptor
	move $s5, $v0 # let s5 be file descriptor for new file
	
	# Now needed files are opened
	# For now:
	# $s1 is source file descriptor
	# $s5 is target file descriptor


##################################################################################		
## LOADING PROCESSING AND SAVING HEADER OF BITMAP
##################################################################################

	addiu $sp,$sp,-54 # make place for header (from old bmp)		
	
	## SYSCALL (read 54B of file to $t0 (place on stack))
	li $v0, 14 # read-from-file service
	move $a0,$s1 # give system file descriptor
	la $a1,0($sp) # show place to write ($t0)
	li $a2,54 # set 54B limit to read (header size)
	syscall # read header of bmp

	# Read bmp dimensions from header just read
	lhu $s2,0x12($sp) # read width (stored on 2B)
	lhu $s3,0x16($sp) # read height (stored on 2B)
	
	## SYSCALL (write 54B from stack to result file (header without any changes))
	li $v0, 15 # write-to-file service
	move $a0, $s5 # give system file dscriptor
	la $a1, 0($sp) # show place to write from ($t0)
	li $a2, 54 #set 54B as number of bytes to write to file
	syscall # write header to reslut file
	
	addiu $sp,$sp,54 # free stack of header information
	
	# Now header is written to target file
	# For now:
	# $s2 is width of image
	# $s3 is height of image
	

##################################################################################		
## JUST END UP PROGRAM IF FILE IS TO SMALL FOR THIS FILTER
##################################################################################

	blt $s2,3,exit # if file is to small
	blt $s3,3,exit # just do nothing about it
	#@todo: probably it should rewrite image without any changes
	
	# Now program ends if file is smaller then 3x3 in at least one dimension
	
##################################################################################		
## CALCULATING LINE SIZE IN BYTES
##################################################################################

	## $t1 - 3 constans
	li $t1,3
	mult $s2,$t1 # 3 bytes describing one pixel in BMP (R,G,B)
	mflo $s6 # assuming 32 bits is enough for line size in bytes
		
	## $t1 - FREE
		
	## $t1 - width mod 4, with is number of bytes in complement
	andi $t1,$s2,0x00000003 # $t4 = width % 4
	addu $s6,$t1,$s6 # $s6 - is actual number of bytes in line now
	
	## $t1 - FREE
	
	# For now:
	# $s6 is number of bytes in line with complement
	
##################################################################################		
## READING FIRST LINES (SAVING ONE OF THEM), PREPARING STACK FOR 4 LINES (3 readed, 1 for progress)
##################################################################################
		
	subu $sp,$sp,$s6 # prepare stack to store the line 1
	sw $sp,tl #save 3rd line pointer
		
	subu $sp,$sp,$s6 # prepare stack to store the line 2
	sw $sp,sl #save 2nd line pointer
	
	subu $sp,$sp,$s6 # prepare stack to store the line 3
	sw $sp,fl #save 1st line pointer
	
	subu $sp,$sp,$s6 # prepare stack to store the result line
	sw $sp,pl #save result (processing) line pointer

	
	## SYSCALL (read first line from source file)
	li $v0, 14 # read-from-file service
	move $a0, $s1 # show system file descriptor
	lw $t0, fl
	la $a1, 0($t0) # show system place for writing
	move $a2, $s6 # limit is the line size
	syscall # read whole line	
	
	## SYSCALL (read second line from source file)		
	## $t0 - place to write to next line
	li $v0, 14 # read-from-file service
	lw $t0, sl
	la $a1, 0($t0)
	syscall # read whole line
	
	## SYSCALL (read third line from source file)
	li $v0, 14 # read-from-file service	
	lw $t0, tl
	la $a1, 0($t0)
	syscall # read whole line	
	## $t0 - FREE	
	
	
	## SYSCALL (write first line to file (it dosn't change anyway)
	li $v0, 15 # write-to-file service
	move $a0, $s5 # show system file descriptor 
	lw $t0, fl
	la $a1, 0($t0) # show system place to read from
	move $a2, $s6 # write a line size from showed pointer
	syscall # write whole line
	
	# Now there is place on stack for 4 lines
	# 3 lines are loaded
	# first line is already in target file
	# There are adresses of begining of first, second, third & processing line in memory under fl,sl,th,pl
	
	
##################################################################################		
## LOOPING THROUGH THE LINES
##################################################################################
			
	## $s7 - loop marker for a while
	move $s7, $s3	
	addu $s7, $s7, -3 #3 lines already loaded
	
	# SYSCALL (printf info about begining of progressing)
	li $v0,4 # print_string service
	la $a0,processing # show adres to read from
	syscall # printf(Processing..)
	
		
p3l_loop: #process 3 lines loops	
	
	# SYSCALL (printf dot for every line you progress)
	li $v0,4 # print_string service
	la $a0,dot # show adress to read from
	syscall # printf(.)
	
##################################################################################		
## NOW 3 LINES ARE ON STACK (showed by fl,sl,tl) ACCTUAL PROCESSING HERE, LOOPING THROUGH BLOCKS IN LINE
##################################################################################

	li $t7, 1 # t7 is acctual pixel (from 1 to width-1)
	addu $sp,$sp,-36 # make place on stack for brightness & pixel id

prl: 

	# WRITE TO RESULT LINE FIRST AND LAST PIXEL (UGLY BUT PROBABLY BETTER THEN LOOP)
	lw $t1, sl
	lw $t2, pl
	lb $t3, 0($t1)
	sb $t3, 0($t2)
	lb $t3, 1($t1)
	sb $t3, 1($t2) 
	lb $t3, 2($t1)
	sb $t3, 2($t2)
	mul $t4,$s2,3
	addu $t1, $t1, $t4
	addu $t2, $t2, $t4
	lb $t3, -3($t1)
	sb $t3, -3($t2)
	lb $t3, -2($t1)
	sb $t3, -2($t2)
	lb $t3, -1($t1)
	sb $t3, -1($t2)
	# WRITE TO RESULT LINE FIRST AND LAST PIXEL - END
	
	# Loading brightness with ids of acctual block		
	beq $t7,$s2,prl_end
	li $t9,0
	lbl:	
		bge $t9,9,lbl_end # only ids 0-8 will be loaded
		move $a0,$t9 # show the procedure id of pixel to load
		jal take_pixel_b #call procedure, there is result in $a0
		mul $t8,$t9,4 # calculete place on stack for becomed value
		addu $t8,$t8,$sp
		sw $a0, 0($t8) # store becomed pair id, brightness
		addiu $t9,$t9,1 # progress next pixel in block
		j lbl
	lbl_end:
	
	
	# Brightness with ids on stack now! sort and change center now.
	
	# Sorting brightnesses with ids (quick buble)
	li $t0,0
	li $t9,1
	sort:
		beq $t0, 5, sort_end
		beqz $t9, sort_end
		li $t1,0
		li $t9, 0
		sort_in:
			li $t8,8
			subu $t8, $t8, $t0
			beq $t1, $t8, sort_in_end
			mul $t2,$t1,4
			addu $t2, $sp, $t2
			lh $t3, 0($t2)
			lh $t4, 4($t2)
			bge $t4,$t3,skip_swap
			li $t9,1
			lw $t3, 0($t2)
			lw $t4, 4($t2)
			sw $t4, 0($t2)
			sw $t3, 4($t2)
			skip_swap:
			addiu $t1,$t1,1
			j sort_in
		sort_in_end:
		addiu $t0,$t0,1
		j sort
	sort_end:	
	
	#brightness sorted here, just change pixel to valid value now
	lw $a0, 16($sp) # show procedure id to take for writing (pair id, brightness in $a0 now)
	srl $a0,$a0,16 #show procedure id to take for writing (only id in $a0 now)
	jal write_pixel # call procedure - it will do rest of things needed
	# now $t0 is valid pixel id
	
	
				
	addiu $t7,$t7,1 # progress next block
	j prl
prl_end:

	addu $sp,$sp,36 # free place on stack needed for brightnesses with ids

	# Now whole line is processed and the result is on place showed by pl

##################################################################################		
## Saving acctual line if it isnt end						
##################################################################################		

	beqz $s7, end_p3l_loop #when no more lines, end loop
	
	## SYSCALL (write line to file)
	li $v0, 15 # write-to-file service
	move $a0, $s5 # show system file descriptor 
	lw $t0, pl
	la $a1, 0($t0) # show system place to read from
	move $a2, $s6 # write a line size from showed pointer
	syscall # write whole line (processed, with is next in order)
	
	## SYSCALL (read next line from source file)
	li $v0, 14 # read-from-file service
	move $a0, $s1 # show system file descriptor
	lw $t0, fl
	la $a1, 0($t0) # show system place for writing
	move $a2, $s6 # limit is the line size
	syscall # read whole line (next in order)
	
	# swap fl,sl,tl (new order)
	## t0,$t1,$t2 - tmp value for swap
	lw $t0,fl
	lw $t1,sl
	lw $t2,tl	
	sw $t1,fl
	sw $t2,sl
	sw $t0,tl
	## t0,$t1,$t2 - free

	addiu $s7,$s7,-1 # process next line
	j p3l_loop # }
end_p3l_loop: 

	# Now all lines are processed and all without last 2 are saved in target file

##################################################################################		
## Saving last two lines, free stack
##################################################################################

	## SYSCALL (write line to file)
	li $v0, 15 # write-to-file service
	move $a0, $s5 # show system file descriptor 
	lw $t0, pl
	la $a1, 0($t0) # show system place to read from
	move $a2, $s6 # write a line size from showed pointer
	syscall # write whole line

	## SYSCALL (write next line to result file)
	li $v0, 15 # write-to-file service
	lw $t0, tl
	la $a1, 0($t0)
	syscall # write whole line

	## $s7 - FREE
	# free stack of line information
	addu $sp,$sp,$s6
	addu $sp,$sp,$s6
	addu $sp,$sp,$s6
	addu $sp,$sp,$s6
	
	# Now all lines are saved and stack is free, its about the end

	
exit:
	## SYSCALL (close source file)
	li $v0, 16 # file-close service
	la $a0, 0($s1) # show system source file descirptor
	syscall # close fd1 (source file)
	
	## SYSCALL (close result file)
	li $v0, 16 # file-close service
	la $a0, 0($s5) # show system result file descriptor
	syscall # close fd2 (result file)
	
	## SYSCALL (print exit msg)
	li $v0, 4 # print_string
	la $a0, thanks # show adress of end msg
	syscall # print(thanks)
	la $a0, new_filename # show adress of end msg param
	syscall # print(thanks_param)
	la $a0, newline # show adress of new line symbol
	syscall # print(nl)
	
	
	## SYSCALL (end program)
	li $v0, 10
	syscall # exit program
	
take_pixel_b: # calculate $a0 pixel in block brightness and save in $a0 with id on more imporant 4 bits, need $t7 (acctual block offset) & fl,sl,tl to be set
	# now sl+t1*pixel_size is acctual block center
	# where pixel_size is 3bytes (R,G,B)	
	ble $a0,2,rfl
	ble $a0,5,rsl
	 
	#read from 3rd line
	lw $t2, tl
	addiu $t6,$a0,-6
	j end_read
	
	rsl:
	#read from 2nd line
	lw $t2, sl 
	addiu $t6,$a0,-3	
	j end_read
	
	rfl:
	#read from 1st line
	lw $t2, fl 	
	move $t6,$a0
	 
	end_read:
	# now $t2 is begin of needed line counter
	# and $t6 is pixel number in this line (with offset in $t0)
	
	mul $t3, $t7, 3
	mul $t6, $t6, 3
	addiu $t3, $t3, -3
	addu $t3, $t3, $t6
	addu $t3, $t3, $t2
	# now $t3 shows needed pixel adress
	
	lb $t4,0($t3)
	andi $t4,$t4,0x000000ff
	lb $t5,1($t3)
	andi $t5,$t5,0x000000ff
	addu $t4,$t4,$t5
	lb $t5,2($t3)
	andi $t5,$t5,0x000000ff
	addu $t4,$t4,$t5
	# t4 is calculated brightness now
	
	sll $a0,$a0,16   #make pair id brightness
	addu $a0,$a0,$t4 #..
	
	jr $ra


write_pixel: # write $a0 pixel to 4pixel in block, need $t7 (acctual block offset) & fl,sl,tl to be set
	# now sl+t1*pixel_size is acctual block center
	# where pixel_size is 3bytes (R,G,B)	
	ble $a0,2,rflw
	ble $a0,5,rslw
	
	#read from 3rd line
	lw $t2, tl
	addiu $t6,$a0,-6
	j end_readw
	
	rslw:
	#read from 2nd line
	lw $t2, sl 
	addiu $t6,$a0,-3	
	j end_readw
	
	rflw:
	#read from 1st line
	lw $t2, fl 	
	move $t6,$a0
	
	end_readw:
	# now $t2 is begin of needed line counter
	# and $t6 is pixel number in this line (with offset in $t0)
	
	mul $t3, $t7, 3
	
	lw $t5,pl
	addu $t5,$t5,$t3
	
	mul $t6, $t6, 3
	addiu $t3, $t3, -3
	addu $t3, $t3, $t6
	addu $t3, $t3, $t2
	# now $t3 shows needed pixel adress
	

	
	lb $t4,0($t3)
	andi $t4,$t4,0x000000ff
	sb $t4,0($t5)
	
	#write new R
	
	lb $t4,1($t3)
	andi $t4,$t4,0x000000ff
	sb $t4,1($t5)
	
	#write new G
	
	lb $t4,2($t3)
	andi $t4,$t4,0x000000ff
	sb $t4,2($t5)
	
	#write new B
	
	jr $ra
