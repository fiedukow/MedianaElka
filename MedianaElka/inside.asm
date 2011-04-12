
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
	
	