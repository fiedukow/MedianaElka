.data
filename:	.asciiz "b.bmp"
new_filename:	.asciiz "output.bmp"
thanks:		.asciiz "Program zakonczyl dzialanie, wynik dzialania zapisano w pliku "
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
	subu $sp,$sp,$s6 # prepare stack to store the line 2
	subu $sp,$sp,$s6 # prepare stack to store the line 3
	# why so? multu, mflo, addu - same time, more illusive (overflow)
	move $t0,$sp  # t0 is now old stack pointer
	
	## $s7 - loop marker for a while
	move $s7, $s3			
p3l_loop: #process 3 lines loops
	ble $s7,0, end_p3l_loop # while( lines_to_read > 0){
	
	## SYSCALL (read next line from source file)
	li $v0, 14 # read-from-file service
	move $a0, $s1 # show system file descriptor
	la $a1, 0($t0) # show system place for writing
	move $a2, $s6 # limit is the line size
	syscall # read whole line	
	
	bge $s7,3,dr3l
	beq $s7,2,dr2l
	j dr1l
	
	dr3l: # do read 3 lines
	## SYSCALL (read next line from source file)		
	## $t2 - place to write to next line
	li $v0, 14 # read-from-file service
	addu $t2,$t0,$s6
	la $a1, 0($t2)
	syscall # read whole line
	
	dr2l: # do read 2 line
	## SYSCALL (read next line from source file)
	li $v0, 14 # read-from-file service	
	addu $t2,$t2,$s6
	la $a1, 0($t2)
	syscall # read whole line
	
	dr1l: # do read 1 line
	
	# why 3 syscalls instead of one loop? it's faster - thats why.
	## $t2 - free
	
##################################################################################		
## NOW 3 LINES ARE ON STACK (showed by $t0), ACCTUAL PROCESSING HERE        
##################################################################################


	addiu $sp, $sp, -36
	move $t1, $sp
	
	li $t4,0
	li $t3,0
	li $t2,0
	li $t8,0
	li $t5,0
	
	# t0 - poczatek fragmentu stosu, skad czytamy (obszar pamieci zawierajacy 3 wczytane z pliku linie)
	# t1 - poczatek fragmentu stosu, gdzie piszemy (obszar pamieci zarezerwowany na wyliczenie jasnosci 9 pixeli)
	
	read_9pixel_loop:
		beq $t2,3,read_9pixel_loop_end
		read_3pixel_loop:
			beq $t3,3,read_3pixel_loop_end
			read_3bytes_loop:
				beq $t4,3,read_3bytes_loop_end
				
				li $t8,3
				mult $t8,$t3
				mflo $t8
				
				addu $t7,$t0,$t8
				
				mult $s6,$t2
				mflo $t8
				
				addu $t7,$t7,$t8 # przesuniecie wynikajace z wiersza bitmapy
				#addu $t7,$t7,$t0
				addu $t7,$t7,$t4 # dodajemy do adresu pobranych danych offset wynikaj¹cy z kroku pêtli
				
				lb $t9, 0($t7) # pobieramy odpowiedni kolor (R, G albo B)
				andi $t9,$t9,0x000000ff # nakladamy maske na odczytany bit, poniewaz lb nie gwarantuje nam co sie stanie z pozostala czescia slowa (dopelnia jedynkami), co mogloby nam popsuc dodawanie (obliczanie brightness'a)
				addu $t6, $t6, $t9 # dodajemy brightness (R+G+B)				
				addiu $t4,$t4,1 # czytaj kolejny bajt
				j read_3bytes_loop
			read_3bytes_loop_end:
						
			li $t8,4
			mult $t5, $t8
			mflo $t8
			
			sll $t4, $t5, 16 # przesuwamy wartosc offsetu na drugi starszy bajt, zeby moc go nastepnie zsumowac z jasnoscia (ID pixela z kratki)
			addu $t6,$t6,$t4
			
			li $t4,0 # przygotuj licznik petli read_3bytes_loop do kolejnego wejscia
			
			addu $t7,$t1,$t8 # dodajemy do adresu pobranych danych offset wynikaj¹cy z obiegu pêtli
			sw $t6,0($t7) # zapisz odczytany brightness pixela (pixel = 3 bajty, brightness = B+B+B = 2B)
			
			li $t6,0 # wyczysc brightness, tak zeby moc wyliczyc go dla nowego pixela w nastepnym obiegu petli
			
			addiu $t3,$t3,1 # kolejny obieg petli
			addiu $t5,$t5,1 # zapamietujemy ogolny offset dla zapisywanych danych
			j read_3pixel_loop
		read_3pixel_loop_end:
		
		li $t3, 0 # przygotuj licznik petli read_3pixel_loop do kolejnego wejscia
		
		addiu $t2,$t2,1 # kolejny obieg petli
		j read_9pixel_loop
	read_9pixel_loop_end:
	
	
	## t2-t9 - FREE
	
	# process brightness (sort + find mediana)
	# t2,t3 loops markers
	li $t2,0
	ls: #sort by brightness for mediana (on stack)
		bge $t2,9,ls_end
		li $t3,0
		lsin:
			bge $t3,9,lsin_end
			mul $t6,$t3,4
			addu $t6,$t1,$t6
			lhu $t4,0($t6)
			lhu $t5,4($t6)
			bgt $t5, $t4, skip_swap
			lb $t7,2($t6)
			sll $t7,$t7,16
			and $t4,$t4,$t7
			lb $t7,6($t6)
			sll $t7,$t7,16
			and $t5,$t5,$t7
			sw $t5,0($t6)
			sw $t4,4($t6)
			skip_swap:
			addiu $t3,$t3,1
			j lsin
		lsin_end:
		addiu $t2,$t2,1
		j ls
	ls_end:
	
	lb $t2, 18($t1) #tmp mediana id
	 
	
	addiu $sp,$sp,36 # zwalniamy stos na brigthnessy
	
	
##################################################################################		
## END OF ACTUAL PROCESSING							
##################################################################################		


	## SYSCALL (write line to file)
	li $v0, 15 # write-to-file service
	move $a0, $s5 # show system file descriptor 
	la $a1, 0($t0) # show system place to read from
	move $a2, $s6 # write a line size from showed pointer
	syscall # write whole line
	
	## @todo: CARE, IF FILE HEIGHT % 3 ISNT EQUAL ZERO THAT WILL NOT WORK
	bge $s7,3,dw3l
	beq $s7,2,dw2l
	j dw1l

	dw3l: # do write 3 lines			
	## SYSCALL (write next line to result file)		
	## $t2 - place to write to next line
	li $v0, 15 # write-to-file service
	addu $t2,$t0,$s6
	la $a1, 0($t2)
	syscall # write whole line

	dw2l: # do write 2 lines		
	## SYSCALL (write next line to result file)		
	li $v0, 15 # write-to-file service
	addu $t2,$t2,$s6
	la $a1, 0($t2)
	syscall # write whole line
	
	dw1l: # do write 1 line
	
	# why 3 syscalls instead of one loop? it's faster - thats why.
	## $t2 - free
	
	addiu $s7,$s7,-3 # we made 3 lines
	j p3l_loop # }
end_p3l_loop:

	# free stack of line information
	addu $sp,$sp,$s6
	## $t0 - FREE
	## $s7 - FREE
	
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
	
	
	## SYSCALL (end program)
	li $v0, 10
	syscall # exit program
	
