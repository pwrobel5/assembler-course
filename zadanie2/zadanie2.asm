ARG_NUMBER		equ 80h
ARG_BEGIN		equ 82h
FNAME_BUFF_LEN  equ 20
BITMAP_HEAD_LEN	equ 14
DIB_HEAD_LEN	equ 40		; dłuższe wersje DIB i tak nieistotne
PALETTE_BYTES	equ 4
PALETTE_24_BIT	equ 3
CLR_NB_PORT		equ 3c8h	; port dla numerów kolorów z palety
CLR_PORT		equ 3c9h	; port do wysyłania składowych palety
VGA_WIDTH		equ 320		; szerokość trybu
VGA_HEIGHT		equ 200		; wysokość trybu
VGA_MEM			equ 0a000h	; początek pamięci obrazu
MAX_SCALE		equ 5

assume cs:code1

data1 segment

	file_name			db	FNAME_BUFF_LEN dup('$')		; nazwa pliku wejściowego
	file_handle			dw  ?							; uchwyt do pliku
	bitmap_header_buff	db  BITMAP_HEAD_LEN dup(?)		; bufor na Bitmap header
	pixel_arr_offset	dw	0							; offset pod którym zaczyna się tablica pikseli
	palette_offset		db	0							; offset dla palety kolorów
	palette_buffer		db  PALETTE_BYTES dup(?)		; bufor do czytania palety
	dib_header_buff		db	DIB_HEAD_LEN dup(?)			; bufor na DIB header
	dib_header_size		db  0							; rozmiar nagłówka DIB
	bitmap_width		dw  0							; szerokość obrazka, nie zakładam obsługi obrazów o rozmiarach niemieszczących się na dwóch bajtach
	bitmap_height		dw	0							; wysokość obrazka
	bits_per_pixel		dw	0							; ilość bitów na piksel
	image_size			dd  0							; rozmiar obrazka
	num_of_colors		dw 	0							; liczba kolorów
	max_crn_x			dw  0							; maksymalna pozycja X dla lewego górnego rogu
	max_crn_y			dw  0							; maksymalna pozycja Y dla lewego górnego rogu (żeby nie przesuwać poza obraz)
	row_with_padding	dw  0							; szerokość wiersza z uwzględnieniem paddingu
	corner_x			dw  0							; współrzędna X pikselu w lewym gównym rogu
	corner_y			dw	0							; współrzędna Y pikselu w lewym gównym rogu
	char_buffer			db  0							; bufor na znak z pliku
	char_buffer_24bit	db  3 dup(?)					; bufor na czytanie z obrazu 24-bitowego
	last_scan_code		db	255							; miejsce do zapisu ostatniego Scan Code'u z klawiatury
	scale_factor		db  0							; wartość do ustalenia skali
	bmp_scaled_width 	dw  0							; przeskalowana wysokość
	bmp_scaled_height	dw	0							; przeskalowana wysokość
	
	; pomoc dla użytkownika
	help_text			db  "Program wczytuje plik BMP podany jako argument jego wywolania w trybie graficznym w 256 kolorach$"
	format_error_text	db  "Niepoprawny format pliku!$"
	len_error_text		db	"Zbyt dluga nazwa pliku!$"
	open_file_error		db	"Blad przy otwieraniu pliku!$"
	
	end_line        	db  10, 13, "$"

data1 ends

code1 segment

start_program:	
	mov  ax,seg ws1						; ustawienie wskaźników stosu
	mov  ss,ax
	mov  sp,offset ws1	
	
	cmp  byte ptr ds:[ARG_NUMBER],0		; jeśli nie podano żadnego argumentu to wyświetlenie pomocy
	jz   print_help
	
	call read_file_name					; wczytanie nazwy pliku, dopóki DS jest nieruszony	
	
	mov  ax,seg data1					; ustawienie wskaźnika segmentu danych
	mov  ds,ax

	mov  al,13h							; uruchomienie trybu graficznego 320 x 200, 256 kolorów
	xor	 ah,ah
	int  10h
	
	in   al,60h							; odczytanie klawisza pamiętanego w buforze żeby nie przeszkadzał
	mov  byte ptr ds:[last_scan_code],al
	
	call open_bmp_file	
	call parse_bmp_file
	call read_image
	
	call keyboard_control
	
end_program:
	call close_bmp_file
	
	mov  al,3h		; przełączenie w tryb tekstowy
	xor  ah,ah
	int  10h

terminate_program:
	mov  ah,4ch		; zakończenie programu
	xor  al,al		; kod wyjścia 0
	int  21h
	
; funkcje pomocnicze

print_help:
	; wyświetlenie tekstu pomocy i zakończenie programu
	mov  dx,offset help_text
	call print_text
	mov  dx,offset end_line
	call print_text
	jmp  terminate_program

print_error_too_long_file_name:
	; wyświetlenie komunikatu o zbyt długiej nazwie pliku
	mov  dx,offset len_error_text
	call print_text
	mov  dx,offset end_line
	call print_text
	jmp  terminate_program

read_file_name:
	; zapisanie do file_name nazwy pliku wczytanej od użytkownika	
	mov  ax,seg file_name				; ustawienie adresu docelowego w ES:DI
	mov  es,ax
	mov  di,offset file_name	
	
	mov  si,ARG_BEGIN					; ustawienie adresu źródłowego w DS:SI - początek bufora w DS:[82h]
	
	xor  cx,cx							; zerowanie CX, wczytana liczba znaków 8-bitowa
	mov  cl,byte ptr ds:[ARG_NUMBER]	; zapis liczby znaków podanych po wywołaniu programu	
	dec  cl								; pierwotnie w DS:ARG_NUMBER przechowywana o 1 za długa liczba uwzględniająca spację
	
	cmp  cl,FNAME_BUFF_LEN				; czy podana nazwa pliku nie jest za długa
	jb   copy_file_name_to_memory
	
	pop  ax								; zdjęcie ze stosu adresu powrotu
	jmp print_error_too_long_file_name
	
	copy_file_name_to_memory:
	cld									; ustawienie DF = 0
	rep  movsb							; przepisanie w pętli danych z DS:SI do ES:DI
	
	mov  byte ptr ds:[di],0				; nazwa pliku musi się kończyć zerem	
	
	ret

print_text:
	; wypisanie tekstu o offsecie zawartym w DX i segmencie w DS
	push ax							; wykorzystane przerwanie 21h, wartość AX odkładana na stos, aby uniknąć utraty danych
	
	mov  ax,seg data1				; ustawienie w DS segmentu danych
	mov  ds,ax
	
	mov  ah,9h						; kod dla wypisania na ekran
	xor  al,al
	int  21h

	pop  ax							; przywrócenie pierwotnej zawartości AX
	ret

open_bmp_file:
	; otwarcie pliku BMP
	push ax							; zrzucenie na stos zawartości używanych rejestrów
	push dx
	
	mov  ax,seg data1				; ustawienie w DS:DX nazwy pliku
	mov  ds,ax
	mov  dx,offset file_name
	
	xor  al,al						; AL = 0 - tryb odczytu
	mov  ah,3dh						; otwarcie pliku
	int  21h
	
	jc   open_error					; jeśli wystąpił błąd to CF = 1
	
	mov  word ptr ds:[file_handle],ax ; zapis uchwytu do pamięci
	
	pop  dx							; przywrócenie zawartości rejestrów i powrót
	pop  ax
	ret
	
	open_error:
	mov  dx,offset open_file_error	; wypisanie tekstu o błędzie
	call print_text
	mov  dx,offset end_line
	call print_text
	pop  ax							; ściągnięcie ze stosu zapisanych wartości
	pop  ax
	pop  ax							; i adresu powrotu
	jmp  end_program				; zakończenie programu

close_bmp_file:
	; zamknięcie pliku BMP
	mov  ax,seg data1				; ustawienie DS
	mov  ds,ax
	
	mov  bx,word ptr ds:[file_handle]	; zapis uchwytu do BX
	mov  ah,3eh						; zamykanie pliku
	int  21h
	ret

read_from_file:
	; odczytuje zadaną liczbę bajtów
	; na wejściu: w CX podana liczba bajtów do przeczytania, w DS:DX adres bufora do zapisu
	
	push bx							; AX i BX będą modyfikowane
	push ax
	
	mov  bx,word ptr ds:[file_handle]	; zapis uchwytu do BX
	mov  ah,3fh						; czytanie z pliku
	int  21h
	
	pop  ax
	pop  bx
	ret

parse_bmp_file:
		; odczyt informacji z pliku BMP
		
		; odczyt nagłówka (Bitmap header)
		mov  cx,BITMAP_HEAD_LEN
		mov  dx,offset bitmap_header_buff
		call read_from_file
		
		; sprawdzenie czy to jest poprawny BMP
		cmp  byte ptr ds:[bitmap_header_buff],'B'
		jnz  not_bmp_format
		cmp  byte ptr ds:[bitmap_header_buff + 1],'M'
		jnz  not_bmp_format
		
		; zapis offsetu początku tablicy pikseli
		mov  ax,word ptr ds:[bitmap_header_buff + 10]
		mov  word ptr ds:[pixel_arr_offset],ax
		jmp read_dib_header
	
	not_bmp_format:
		; jeśli nie, wyświetl komunikat o błędzie
		mov  dx,offset format_error_text
		call print_text
		pop  ax						; zdjęcie adresu powrotu
		jmp  end_program			; koniec programu
	
	read_dib_header:
		; odczyt dalszej części nagłówka (DIB header)
		mov  cx,DIB_HEAD_LEN
		mov  dx,offset dib_header_buff
		call read_from_file
		
		; odczyt rozmiaru DIB headera
		mov  al,byte ptr ds:[dib_header_buff]
		mov  byte ptr ds:[dib_header_size],al
		
		; obliczenie offsetu palety kolorów
		add  al,BITMAP_HEAD_LEN
		mov  byte ptr ds:[palette_offset],al
		
		; odczyt szerokości obrazka
		mov  ax,word ptr ds:[dib_header_buff + 4]
		mov  word ptr ds:[bitmap_width],ax
		
		; odczyt wysokości obrazka
		mov  ax,word ptr ds:[dib_header_buff + 8]
		mov  word ptr ds:[bitmap_height],ax
		
		; liczba bitów na piksel
		mov  ax,word ptr ds:[dib_header_buff + 14]
		mov  word ptr ds:[bits_per_pixel],ax
		
		; rozmiar obrazka
		mov  ax,word ptr ds:[dib_header_buff + 20]
		mov  word ptr ds:[image_size],ax
		mov  ax,word ptr ds:[dib_header_buff + 22]
		mov  word ptr ds:[image_size + 2],ax
		
		; obliczenie rzeczywistej szerokości wiersza z uwzględnieniem paddingu
		; źródło: https://en.wikipedia.org/wiki/BMP_file_format#Pixel_storage
		mov  ax,word ptr ds:[bits_per_pixel]
		mov  bx,word ptr ds:[bitmap_width]
		mul  bx										; mnożenie BX * AX
		add  ax,31									; dodanie 31, żeby można było potem liczyć podłogę i nie przejmować się utraconymi bitami
		mov  cl,5
		shr  ax,cl									; dzielenie przez 32, DX pomijamy, założenie o obrazie o niezbyt dużym rozmiarze - mnożenie razy 24 przekroczy 16 bitów dopiero dla szerokości około 2000 pikseli
		mov  cl,2
		shl  ax,cl									; mnożenie razy 4
		mov  word ptr ds:[row_with_padding],ax		; zapis do pamięci		
		
		; obliczenie maksymalnych X i Y lewego górnego wierzchołka, dla których nie wyjdzie się poza obraz
		cmp  word ptr ds:[bitmap_width],VGA_WIDTH	; czy obrazek jest węższy niż szerokosć trybu
		ja   set_max_x
		mov  word ptr ds:[max_crn_x],0				; jeśli tak to nie będziemy go ruszać
		jmp  check_height_for_max_y
		
		set_max_x:
			mov  ax,word ptr ds:[bitmap_width]
			sub  ax,VGA_WIDTH
			inc  ax
			mov  word ptr ds:[max_crn_x],ax
		
		check_height_for_max_y:
			cmp  word ptr ds:[bitmap_height],VGA_HEIGHT	; analogicznie sprawdzamy czy obrazek nie ma mniejszej wysokości niż tryb VGA
			ja   set_max_y
			mov  word ptr ds:[max_crn_y],0				; jeśli tak to nie będziemy go ruszać
			jmp  read_bits_per_pixel
		
		set_max_y:
			mov  ax,word ptr ds:[bitmap_height]
			sub  ax,VGA_HEIGHT
			inc  ax
			mov  word ptr ds:[max_crn_y],ax
		
		read_bits_per_pixel:
			; odczyt palety kolorów
			cmp  word ptr ds:[bits_per_pixel],1			; dla monochromatycznego koniec
			jz   end_parsing
			
			cmp  word ptr ds:[bits_per_pixel],8			; jeśli liczba bitów na piksel <= 8 to odczyt palety z pliku
			ja   parse_24_bit
			call read_color_palette
			jmp  end_parsing
		
	parse_24_bit:
		call read_palette_24bit						; dla 24-bitowej bitmapy odczyt kolorów bezpośrednio z obrazu
	
	end_parsing:		
		ret

read_color_palette:
	; odczyt palety kolorów dla obrazów co najwyżej 8-bitowych
	push ax
	push cx
	push bx
	push dx
	
	mov  ax,1										; wyznaczenie liczby kolorów jako 2^l.bitów na piksel - 1
	mov  cl,byte ptr ds:[bits_per_pixel]			; tu i tak liczba bitów na piksel wynosi max 8, więc mieści się w jednym bajcie
	shl  ax,cl
	mov  word ptr ds:[num_of_colors],ax
	
	xor  al,al										; skok od początku pliku
	mov  bx,word ptr ds:[file_handle]				; uchwyt do pliku w BX
	xor  cx,cx	
	xor  dh,dh
	mov  dl,byte ptr ds:[palette_offset]			; w CX:DX offset
	mov  ah,42h										; numer funkcji przerwania "LSEEK"
	int  21h										; skok w pliku do pozycji palety
	
	mov  cx,word ptr ds:[num_of_colors]				; ustawienie licznika do pętli
	mov  dx,CLR_NB_PORT
	mov  al,0
	out  dx,al										; ustawienie numeru pierwszego koloru
	
	read_colors:									; pętla odczytu kolorów
	
		push cx										; CX będzie zmieniany do funkcji read_from_file
		
		mov  cx,PALETTE_BYTES							
		mov  dx,offset palette_buffer
		call read_from_file							; odczyt kolejnego koloru z palety
		
		mov  dx,CLR_PORT							; ustawienie numeru portu w DX
		
		; kolory w palecie zapisane w kolejności odwrotnej: BGR		
		; składowa czerwona
		mov  al,byte ptr ds:[palette_buffer + 2]
		mov  cl,2									; do przesunięć bitowych
		shr  al,cl									; żeby nie dostać wartości >= 64
		out  dx,al
		
		; składowa zielona
		mov  al,byte ptr ds:[palette_buffer + 1]
		shr  al,cl
		out  dx,al
		
		; składowa niebieska
		mov  al,byte ptr ds:[palette_buffer]
		shr  al,cl
		out  dx,al
		
		; wartość indeksu koloru w porcie 3c8h automatycznie się aktualizuje po dodaniu 3 wartości do 3c9h
		
		pop  cx
		loop read_colors							
	
	pop  dx
	pop  bx
	pop  cx
	pop  ax
	
	ret
	
make_rgb_index:
	; przerabia wartości 3-bitową R, 3-bitową G i 2-bitową B na 8-bitowy indeks koloru
	; wejście: R w BL, G w BH, B w AH
	; wyjście: index w AL
	push cx
	push dx
	
	mov  cl,5
	mov  al,bl
	shl  al,cl
	
	mov  cl,2
	mov  dl,bh
	shl  dl,cl
	add  al,dl
	
	add  al,ah
	
	pop  dx
	pop  cx
	ret
	
read_palette_24bit:
	; odczyt palety kolorów dla obrazów 24-bitowych
	push ax
	push cx
	push bx
	push dx
	
	xor  al,al										; skok od początku pliku
	mov  bx,word ptr ds:[file_handle]				; uchwyt do pliku w BX
	xor  cx,cx	
	xor  dh,dh
	mov  dl,byte ptr ds:[pixel_arr_offset]			; w CX:DX offset, czytać będziemy bezpośrednio z tablicy pikseli
	mov  ah,42h										; numer funkcji przerwania "LSEEK"
	int  21h										; skok w pliku do pozycji palety
	
	mov  cx,word ptr ds:[bitmap_height]				; ustawienie licznika do pętli
		
	read_colors_rows:								; pętla po wierszach
	
		push cx										; CX będzie zmieniany do funkcji read_from_file
		
		mov  cx,word ptr ds:[bitmap_width]
		
		read_colors_in_row:							; pętla przez wiersz
		
			push cx
			
			mov  cx,PALETTE_24_BIT						
			mov  dx,offset palette_buffer
			call read_from_file							; odczyt kolejnego koloru z palety
			
			; kolory w palecie zapisane w kolejności odwrotnej: BGR		
			; składowa czerwona
			mov  al,byte ptr ds:[palette_buffer + 2]
			mov  cl,5									; do przesunięć bitowych
			shr  al,cl									; żeby dostać wartość 3-bitową
			mov  bl,al
			
			; składowa zielona
			mov  al,byte ptr ds:[palette_buffer + 1]
			shr  al,cl
			mov  bh,al
			
			; składowa niebieska
			mov  al,byte ptr ds:[palette_buffer]
			inc  cl										; żeby dostać wartość 2-bitową
			shr  al,cl
			mov  ah,al
			
			call make_rgb_index							; przeliczenie na indeks
			
			mov  dx,CLR_NB_PORT							; wysłanie indeksu do portu
			out  dx,al
			
			; składowa czerwona
			mov  dx,CLR_PORT
			mov  al,bl
			out  dx,al
			
			; składowa zielona
			mov  al,bh
			out  dx,al
			
			; składowa niebieska
			mov  al,ah
			out  dx,al
			
			pop cx
			loop read_colors_in_row
		
		pop  cx
		loop read_colors_rows
	
	pop  dx
	pop  bx
	pop  cx
	pop  ax
	
	ret

skip_lines:
	; opuszczanie linijki w pliku
	; w bx uchwyt do pliku
	; w dx długość linijki
	
	push ax
	push cx
	
	mov  al,01h		; przesunięcie od bieżącej pozycji
	xor  cx,cx
	mov  ah,42h
	int  21h
	
	pop  cx
	pop  ax
	ret

read_image:
	; wczytanie obrazka
	push ax
	push bx
	push cx
	push dx
	
	; przeliczenie wysokości i szerokości na wielkości przeskalowane
	mov  cl,byte ptr ds:[scale_factor]
	mov  ax,word ptr ds:[bitmap_height]
	shr  ax,cl
	mov  word ptr ds:[bmp_scaled_height],ax
	mov  ax,word ptr ds:[bitmap_width]
	shr  ax,cl
	mov  word ptr ds:[bmp_scaled_width],ax
	
	; przejście do początku tablicy pikseli
	xor  al,al								; od początku pliku
	mov  bx,word ptr ds:[file_handle]		; uchwyt do pliku w BX
	xor  cx,cx					
	mov  dx,word ptr ds:[pixel_arr_offset]	; w CX:DX zapisano jak daleko się przesunąć
	mov  ah,42h
	int  21h
	
	cmp  word ptr ds:[bmp_scaled_height],VGA_HEIGHT	; czy wysokość obrazu jest mniejsza niż wysokość w trybie VGA_HEIGHT
	ja   count_lines_to_skip					; jeśli nie to liczenie ile linijek pominąć
	mov  si,word ptr ds:[bmp_scaled_height]		; zapis w SI wartości y od jakiej należy zacząć wczytywanie obrazu
	dec  si
	jmp  read_data								; przeskok do wczytywania

	count_lines_to_skip:
		; obliczenie ilości linijek do pominięcia: wysokość - 199 - Y wierzchołka
		mov  bx,word ptr ds:[bmp_scaled_height]
		mov  ax,VGA_HEIGHT
		mov  cl,byte ptr ds:[scale_factor]
		shl  ax,cl
		sub  bx,word ptr ds:[corner_y]
		sub  bx,ax
		mov  cx,bx
	
	; jeśli nie ma nic do pominięcia, to skok do ustawienia SI na ostatni wiersz VGA_HEIGHT
	cmp  cx,0
	jbe  set_si
	
	omit_lines_loop:							; pominięcie kolejnych linii
		push cx
		
		mov  bx,word ptr ds:[file_handle]
		mov  dx,word ptr ds:[row_with_padding]
		call skip_lines
		
		pop  cx
		loop omit_lines_loop
	
	set_si:
		; SI pokazuje bieżący wiersz w VGA - zaczynamy rysowanie od dołu
		cmp  word ptr ds:[bmp_scaled_height],VGA_HEIGHT
		ja   set_max_si
		mov  si,word ptr ds:[bmp_scaled_height]
		jmp  read_data
		
		set_max_si:
		mov  si,199
	
	read_data:
		; do CX trafia liczba linii do przeczytania - pozycja SI + 1
		mov  cx,si
		inc  cx

		cmp  word ptr ds:[bmp_scaled_width],VGA_WIDTH		; czy obraz ma szerokość mniejszą od szerokości trybu VGA
		ja   set_vga_width									; jeśli nie, to ustawiona w AX szerokość VGA
		mov  ax,word ptr ds:[bmp_scaled_width]				; jeśli tak to do AX trafia szerokość obrazu
		jmp  set_di
		
		set_vga_width:
			mov  ax,VGA_WIDTH
		
		set_di:
			; DI zawiera liczbę znaków z końca wiersza do pominięcia, zawsze jest, o ile występuje padding
			mov  di,word ptr ds:[row_with_padding]
			push cx
			mov  cl,byte ptr ds:[scale_factor]
			
			shl  ax,cl
			
			mov  cx,1
			cmp  byte ptr ds:[bits_per_pixel],24
			jnz  loop_set_di
			mov  cx,3
			
			loop_set_di:
				sub  di,ax										; AX zawiera liczbę do odjęcia w zależności od szerokości grafiki
				sub  di,word ptr ds:[corner_x]
				loop loop_set_di
			pop  cx	
		set_es:
		; ustawienie w ES wskaźnika segmentu obrazu
		mov  ax,VGA_MEM
		mov  es,ax
		
		read_lines_loop:						; czytanie kolejnych wierszy
			push cx
			
			skip_first_characters:				; jeśli X dla lewego górnego rogu jest niezerowe to pomijamy odpowiednią ilosć znaków
				cmp  word ptr ds:[corner_x],0
				jz   calculate_offset
				mov  cx,1
				
				cmp  byte ptr ds:[bits_per_pixel],24
				jnz  skip_first_characters_loop
				mov  cx,3
				
				skip_first_characters_loop:
					mov  bx,word ptr ds:[file_handle]
					mov  dx,word ptr ds:[corner_x]
					call skip_lines
					loop skip_first_characters_loop
			
			calculate_offset:
				; obliczenie offsetu do pamięci obrazu, trzymany w BX
				mov  ax,si
				mov  bx,320
				mul  bx	
				mov  bx,ax
				
			read_characters:					; czytanie wiersza
				mov  cx,VGA_WIDTH
				cmp  word ptr ds:[bmp_scaled_width],VGA_WIDTH	; sprawdzenie czy obraz nie jest węższy niż wiersz
				ja   read_characters_loop					; jeśli nie to przejście do pętli
				mov  cx,word ptr ds:[bmp_scaled_width]			; jeśli tak to zmiana licznika na szerokość obrazu
				
				read_characters_loop:
					push cx
					
					; obliczenie ile znaków wczytać (uwzględniając skalę)
					xor  cx,cx
					mov  cl,byte ptr ds:[scale_factor]
					mov  ax,1
					shl  ax,cl
					mov  cx,ax
					
					read_characters_with_scale:
						push cx
						mov  cx,1					; czytany 1 bajt z pliku
						cmp  byte ptr ds:[bits_per_pixel],24
						jnz  read_8bit
						
						mov  cx,3
						mov  dx,offset char_buffer_24bit
						call read_from_file
						
						push bx
						push ax
						
						; czerwony
						mov  bl,byte ptr ds:[char_buffer_24bit + 2]
						; zielony
						mov  bh,byte ptr ds:[char_buffer_24bit + 1]
						; niebieski
						mov  ah,byte ptr ds:[char_buffer_24bit]
						call make_rgb_index
						mov  byte ptr ds:[char_buffer],al
						
						pop  ax
						pop  bx
						
						jmp  take_loop
						
						read_8bit:
							mov  dx,offset char_buffer	; adres bufora w DS:DX
							call read_from_file			; odczytanie piksela z pliku
						
						take_loop:
							pop  cx
							loop read_characters_with_scale
					
					mov  al,byte ptr ds:[char_buffer]
					mov  byte ptr es:[bx],al	; zapis na ekran
					
					inc  bx						; zwiększenie offsetu do zapisu na ekran o 1
					pop  cx
					loop read_characters_loop
				
				skip_least_chars:				; ominięcie nadmiarowych bajtów z linijki
					cmp  di,0					; sprawdzenie czy należy jakiekolwiek pominąć
					jz   read_lines_loop_ending	; jeśli nie ma potrzeby to przejście do końca pętli
					
					mov  bx,word ptr ds:[file_handle]
					mov  dx,di					; DI - liczba bajtów do pominięcia
					call skip_lines
			
				skip_lines_with_scale:
					; liczba linii do opuszczenia - 2^skala - 1
					mov  cl,byte ptr ds:[scale_factor]
					mov  ax,1
					shl  ax,cl
					dec  ax
					cmp  ax,0
					jz read_lines_loop_ending	; jeśli nie zostało nic do opuszczenia (skala 1:1) to przechodzimy dalej
					
					mov  cx,ax
					
					skip_lines_scale_loop:
						push cx
						push bx
						push dx
						
						mov  bx,word ptr ds:[file_handle]
						mov  dx,word ptr ds:[row_with_padding]
						call skip_lines
						
						pop  dx
						pop  bx
						pop  cx
						
						loop skip_lines_scale_loop
			
			read_lines_loop_ending:
			
			dec  si	
			pop  cx
			
			dec  cx
			jnz  read_lines_loop		; za długi skok żeby użyć loop
	
	pop  dx
	pop  cx
	pop  bx
	pop  ax
	ret

clear_keyboard_buffer:		; czyści bufor klawiatury, potrzebne żeby po wyjściu nic nie zostało w wierszu poleceń
		xor  ax,ax			; al jest wcześniej używane, wiec zerowany jest cały ax
		mov  ah,0ch			
		int  21h			
		ret

keyboard_control:
	; obsługa klawiatury
	call clear_keyboard_buffer					; wyczyszczenie bufora na początek
	
	begin_reading:								; dopóki otrzymany scancode taki sam jak wcześniej to nic nie rób
		in   al,60h
		cmp  al,byte ptr ds:[last_scan_code]
		jz   keyboard_control
		mov  byte ptr ds:[last_scan_code],al	; zapis ostatniego scan code'u

	escape_key:									; klawisz ESC - wyjście z programu (i funkcji)
		cmp  al,01h
		jnz  left_arrow_key
		ret
		
	left_arrow_key:
		cmp  al,4bh
		jnz  right_arrow_key
		
		cmp  word ptr ds:[corner_x],5			; sprawdzenie czy można jeszcze przesuwać w lewo
		jbe  keyboard_control
		
		mov  bx,word ptr ds:[corner_x]
		sub  bx,6
		mov  word ptr ds:[corner_x],bx 			; jeśli można to obniżenie wartości X wierzchołka o 6		
		call read_image							; ponowne wczytanie obrazka
		jmp  keyboard_control
		
	right_arrow_key:
		cmp  al,4dh
		jnz  down_arrow_key
		
		mov  bx,word ptr ds:[max_crn_x]			; zapis do BX do porównania
		cmp  bx,0								; czy maksymalny X nie jest ustawiony na 0
		jz   keyboard_control
		sub  bx,5
		cmp  word ptr ds:[corner_x],bx			; czy obecny X nie jest maksymalny
		jae  keyboard_control
		
		mov  bx,word ptr ds:[corner_x]
		add  bx,6
		mov  word ptr ds:[corner_x],bx			; jeśli można to podwyższenie wartości X wierzchołka o 6
		call read_image							; ponowne wczytanie obrazka
		jmp  keyboard_control
		
	down_arrow_key:
		cmp  al,50h
		jnz  up_arrow_key
		
		mov  bx,word ptr ds:[max_crn_y]			; zapis do BX do porównania
		cmp  bx,0								; czy maksymalny Y nie jest ustawiony na 0
		jz   keyboard_control
		sub  bx,5
		cmp  word ptr ds:[corner_y],bx			; czy obecny Y nie jest maksymalny
		jae  keyboard_control
		
		mov  bx,word ptr ds:[corner_y]
		add  bx,6
		mov  word ptr ds:[corner_y],bx			; jeśli można to podwyższenie wartości Y wierzchołka o 5
		call read_image							; ponowne wczytanie obrazka
		jmp  keyboard_control
	
	up_arrow_key:
		cmp  al,48h
		jnz  num_plus_key
		
		cmp  word ptr ds:[corner_y],4			; czy można jeszcze przesunąć do góry
		jbe  keyboard_control
		
		mov  bx,word ptr ds:[corner_y]
		sub  bx,5
		mov  word ptr ds:[corner_y],bx 			; jeśli można to obniżenie wartości Y wierzchołka o 5
		call read_image							; ponowne wczytanie obrazka
		jmp keyboard_control
	
	num_plus_key:
		cmp  al,4eh
		jnz  num_minus_key
		
		cmp  byte ptr ds:[scale_factor],0
		jz   keyboard_control					; czy można jeszcze przybliżyć
		
		dec  byte ptr ds:[scale_factor]			; jeśli można, to zmniejszamy czynnik skali o 1
		mov  word ptr ds:[corner_x],0			; przesunięcie obrazu do początku
		mov  word ptr ds:[corner_y],0
		
		call clear_screen
		call read_image
		call set_x_y_max
		jmp  keyboard_control
		
	num_minus_key:
		cmp  al,4ah
		jnz  keyboard_control
		
		cmp  byte ptr ds:[scale_factor],MAX_SCALE	; czy można jeszcze pomniejszyć
		jz   keyboard_control
		
		inc  byte ptr ds:[scale_factor]
		mov  word ptr ds:[corner_x],0			; przesunięcie obrazu do początku
		mov  word ptr ds:[corner_y],0
		
		call clear_screen
		call read_image
		call set_x_y_max
		jmp  keyboard_control

clear_screen:
	; czyści ekran VGA
	push ax
	push cx
	push di
	
	mov  ax,VGA_MEM
	mov  es,ax
	mov  di,0
	
	mov  cx,64000
	
	clear_screen_loop:
		mov  byte ptr es:[di],0
		inc  di
		loop clear_screen_loop
	
	pop  di
	pop  cx
	pop  ax
	ret
	
set_x_y_max:
	; poprawia po przeskalowaniu wartości maksymalne X i Y
	check_height:
		cmp  word ptr ds:[bmp_scaled_height],VGA_HEIGHT
		ja   set_normal_max_height
		mov  word ptr ds:[max_crn_y],0
		jmp  check_width
	
	set_normal_max_height:
		mov  ax,word ptr ds:[bmp_scaled_height]
		sub  ax,VGA_HEIGHT
		inc  ax
		mov  word ptr ds:[max_crn_y],ax
		
	check_width:
		cmp  word ptr ds:[bmp_scaled_width],VGA_WIDTH
		ja   set_normal_max_width
		mov  word ptr ds:[max_crn_x],0
		jmp  end_setting_max_x_y
		
	set_normal_max_width:
		mov  ax,word ptr ds:[bmp_scaled_width]
		sub  ax,VGA_WIDTH
		inc  ax
		mov  word ptr ds:[max_crn_x],ax
		
	end_setting_max_x_y:
		ret
	
code1 ends

stack1 segment stack

		dw 400 dup(?)	; 800 bajtów stosu
	ws1	dw ?			; wierzchołek

stack1 ends

end start_program