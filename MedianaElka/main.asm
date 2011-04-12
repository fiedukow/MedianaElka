.data
filename:	.asciiz "long.bmp"
new_filename:	.asciiz "output.bmp"
thanks:		.asciiz "Program zakonczyl dzialanie, wynik dzialania zapisano w pliku "

.align 2
fl: .space 4 # current 1st line pointer
sl: .space 4 # current 2nd line pointer
tl: .space 4 # current 3rd line pointer

.text
main:	

# s0 - source file name
# s1 - file descriptor of source
# s2 - width (same for both files)
# s3 - height (same for both files)
# s4 - result filename
# s5 - file descriptor of result
# s6 - bytes in one line with complement


	## SYSCALL (open file for reading, $s1 is file descriptor)
	li $v0, 13 # open-file service
	la $a0, filename # 0($s0) # set filename to read
	li $a1, 0 # read-only flag
	li $a2, 0 # ignore mode
	syscall # open file, $v0 gets file-descriptior	
	move $s1, $v0 # let s1 be file descriptor for old file
	
	## $t0 - old stack pointer
	

	addiu $sp,$sp,-54 # make place for header (from old bmp)		
	move $t0,$sp # t0 is now old stack pointer	
	
	## SYSCALL (read 54B of file to $t0 (place on stack))
	li $v0, 14 # read-from-file service
	move $a0,$s1 # give system file descriptor
	la $a1,0($t0) # show place to write ($t0)
	li $a2,54 # set 54B limit to read (header size)
	syscall # read header of bmp

	# Read bmp dimensions from header just read
	lhu $s2,0x12($t0) # read width (stored on 2B)
	lhu $s3,0x16($t0) # read height (stored on 2B)
	
	## SYSCALL (open file for writing (for save the result of program))
	li $v0, 13 # open-file service
	la $a0, new_filename # show file to write to
	li $a1, 1 # write flag
	li $a2, 0 # ignore mode
	syscall # open result file for writing, $v0 gets descriptor
	move $s5, $v0 # let s5 be file descriptor for new file
	
	## SYSCALL (write 54B from stack to result file (header without any changes))
	li $v0, 15 # write-to-file service
	move $a0, $s5 # give system file dscriptor
	la $a1, 0($t0) # show place to write from ($t0)
	li $a2, 54 #set 54B as number of bytes to write to file
	syscall # write header to reslut file
	
	addiu $sp,$sp,54 # free stack of header information
	## $t0 - FREE
	
	blt $s2,3,exit # if file is to small
	blt $s3,3,exit # just do nothing about it
	#@todo: probably it should rewrite image without any changes

	## $t1 - 3 constans
	li $t1,3
	mult $s2,$t1 # 3 bytes describing one pixel in BMP (R,G,B)
	mflo $s6 # assuming 32 bits is enough for line size in bytes
		
	## $t1 - FREE
		
	## $t1 - width mod 4, with is number of bytes in complement
	andi $t1,$s2,0x00000003 # $t4 = width % 4
	addu $s6,$t1,$s6 # $s6 - is actual number of bytes in line now
	
	## $t1 - FREE
	
	## $t0 - old stack pointer
	
	subu $sp,$sp,$s6 # prepare stack to store the line 1
	sw $sp,tl #save 3rd line pointer
		
	subu $sp,$sp,$s6 # prepare stack to store the line 2
	sw $sp,sl #save 2nd line pointer
	
	subu $sp,$sp,$s6 # prepare stack to store the line 3
	sw $sp,fl #save 1st line pointer
	
	
	## SYSCALL (read next line from source file)
	li $v0, 14 # read-from-file service
	move $a0, $s1 # show system file descriptor
	lw $t0, fl
	la $a1, 0($t0) # show system place for writing
	move $a2, $s6 # limit is the line size
	syscall # read whole line	
	
	## SYSCALL (read next line from source file)		
	## $t0 - place to write to next line
	li $v0, 14 # read-from-file service
	lw $t0, sl
	la $a1, 0($t0)
	syscall # read whole line
	
	## SYSCALL (read next line from source file)
	li $v0, 14 # read-from-file service	
	lw $t0, tl
	la $a1, 0($t0)
	syscall # read whole line
	
	## $t0 - FREE
	
	
	## $s7 - loop marker for a while
	move $s7, $s3	
	addu $s7, $s7, -3 #3 lines already loaded
		
p3l_loop: #process 3 lines loops	
	
##################################################################################		
## NOW 3 LINES ARE ON STACK (showed by $t0), ACCTUAL PROCESSING HERE        
##################################################################################


##################################################################################		
## END OF ACTUAL PROCESSING							
##################################################################################		




	beqz $s7, end_p3l_loop #when no more lines, end loop
	
	## SYSCALL (write line to file)
	li $v0, 15 # write-to-file service
	move $a0, $s5 # show system file descriptor 
	lw $t0, fl
	la $a1, 0($t0) # show system place to read from
	move $a2, $s6 # write a line size from showed pointer
	syscall # write whole line
	
	## SYSCALL (read next line from source file)
	li $v0, 14 # read-from-file service
	move $a0, $s1 # show system file descriptor
	lw $t0, fl
	la $a1, 0($t0) # show system place for writing
	move $a2, $s6 # limit is the line size
	syscall # read whole line	
	
	## t0,$t1,$t2 - tmp value for swap
	lw $t0,fl
	lw $t1,sl
	lw $t2,tl	
	sw $t1,fl
	sw $t2,sl
	sw $t0,tl
	## t0,$t1,$t2 - free

	addiu $s7,$s7,-1 # we made 3 lines
	j p3l_loop # }
end_p3l_loop:

	#@todo: save last 3 lines manualy
	## SYSCALL (write line to file)
	li $v0, 15 # write-to-file service
	move $a0, $s5 # show system file descriptor 
	lw $t0, fl
	la $a1, 0($t0) # show system place to read from
	move $a2, $s6 # write a line size from showed pointer
	syscall # write whole line
	
	## SYSCALL (write next line to result file)
	li $v0, 15 # write-to-file service
	lw $t0, sl
	la $a1, 0($t0)
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
	#la $a0, newline # show adress of new line symbol
	#syscall # print(nl)
	
	
	## SYSCALL (end program)
	li $v0, 10
	syscall # exit program
	
