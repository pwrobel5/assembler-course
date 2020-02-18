assume cs:code1						; kod zapisany w segmencie code1

data1 segment						; segment danych

	buffer				db 255 dup('$')
	char_buffer			db 2 dup('$')
	operator_buffer		db 0		; miejsce do zapisu operatora, 0 oznacza nic
	first_number		db 0		; pierwsza wczytana cyfra
	second_number		db 0		; druga wczytana cyfra
	last_scan_code		db 234		; wartość taka, żeby to nie odpowiadało żadnemu istotnemu klawiszowi
	read_characters		dw 1 dup(0)	; długość zapisanego ciągu znaków
	
	; komunikaty dla uzytkownika - poczatek programu, podanie wyniku, sygnalizacja bledu
	welcome_text_1		db "Prosty kalkulator slowny$" 
	welcome_text_2		db "Naciskajac klawisz ? mozna uzyskac pomoc$"
	welcome_text_3		db "Klawisz ESC konczy dzialanie programu$"
	entry_text			db "Wprowadz slowny opis dzialania: $"
	result_text			db "Wynikiem jest: $"
	error_text 			db "Blad danych wejsciowych!$"
	buffer_overflow		db "Przepelnienie bufora!$"
	
	; tekst pomocy
	help_txt_1			db "Program oblicza wartosc wyrazenia podanego slownie$"
	help_txt_2			db "Obslugiwane sa cyfry zapisane slownie bez polskich znakow$"
	help_txt_3			db "Dostepne dzialania: dodawanie (plus), odejmowanie (minus) i mnozenie (razy)$"
	help_txt_4			db "Przykladowe wywolanie:$"
	help_txt_5			db "piec plus cztery$"
	help_txt_6			db "dziewiec$"
	
	; teksty odpowiadajace liczbom
	zero_text			db "zero$"
	one_text			db "jeden$"
	two_text			db "dwa$"
	three_text			db "trzy$"
	four_text			db "cztery$"
	five_text			db "piec$"
	six_text 			db "szesc$"
	seven_text			db "siedem$"
	eight_text			db "osiem$"
	nine_text			db "dziewiec$"
	ten_text			db "dziesiec$"
	eleven_text			db "jedenascie$"
	twelve_text			db "dwanascie$"
	thirteen_text		db "trzynascie$"
	fourteen_text		db "czternascie$"
	fifteen_text		db "pietnascie$"
	sixteen_text		db "szesnascie$"
	seventeen_text		db "siedemnascie$"
	eighteen_text		db "osiemnascie$"
	nineteen_text		db "dziewietnascie$"
	twenty_text			db "dwadziescia$"
	thirty_text			db "trzydziesci$"
	forty_text			db "czterdziesci$"
	fifty_text			db "piecdziesiat$"
	sixty_text			db "szescdziesiat$"
	seventy_text		db "siedemdziesiat$"
	eighty_text			db "osiemdziesiat$"
	ninety_text			db "dziewiecdziesiat$"
	
	; teksty odpowiadajace dzialaniom
	add_text			db "plus$"
	subtract_text		db "minus$"
	multiply_text		db "razy$"

	; zakonczenie linii i spacja
	space_text			db " $"
	end_line			db 10, 13, "$"
	
data1 ends

code1 segment

init_stack:							; inicjacja stosu		
		mov  ax,seg ws1				; zapis ws1 do ax, bo bezpośrednio do ss nie można
		mov  ss,ax					; ss przechowuje segment wierzchołka stosu
		mov  sp,offset ws1			; offset wierzchołka stosu przechowywany w sp

		; ustawienie wskaźnika segmentu danych	
		mov  ax,seg data1
		mov  ds,ax					; w ds jest teraz trzymany segment danych

		call print_welcome_text 	; wypisanie tekstu wprowadzającego
		call print_entry_text		; wypisanie tekstu zachęty

		; przy wywołaniu programu wejście 60h posiada zapisany ostatni wciśnięty wcześniej klawisz
		; należy go pominąć żeby potem nie przeszkadzał
		call read_char

start_reading:		
		; czytamy tekst do bufora
		call read_to_buffer

	check_first_word:
		; pomijamy ewentualne białe znaki z początku, BX ustawiany, bo funkcja omit_white_characters wymaga
		; podania w BX offsetu od którego rozpoczynamy przeszukiwanie
		mov bx,offset buffer
		call omit_white_characters
		
		; zapisanie w bx wskaźnika na pierwszy znak (wymagane do funkcji compare_number)
		mov bx,di
		call compare_number
		
		; sprawdzenie czy wprowadzono poprawny tekst
		; jeśli nie, to w al jest wartość 10
		cmp al,10
		jnz save_first_number
		; dla złego słowa wyświetlenie komunikatu błędu, wyczyszczenie bufora i przejście do początku
		call print_error_text
		jmp clean_and_return_to_beginning
	
	save_first_number:
		mov byte ptr ds:[first_number],al
	
	check_second_word:	
		; zapisanie w BX wskaźnika do pierwszego znaku po słowie
		mov bx,di
		call omit_white_characters	
	
		; zapisanie do BX wskaźnika na pierwszy znak drugiego słowa
		mov bx,di
		call compare_operator
		
		; sprawdzenie czy wprowadzono poprawny tekst
		; jeśli nie, to w al jest wartość 10
		cmp al,10
		jnz save_operator
		; dla złego słowa wyświetlenie komunikatu błędu, wyczyszczenie bufora i przejście do początku
		call print_error_text
		jmp clean_and_return_to_beginning
	
	save_operator:
		mov byte ptr ds:[operator_buffer],al
	
	check_third_word:
		; zapisanie w BX wskaźnika do pierwszego znaku po słowie
		mov bx,di
		call omit_white_characters
		
		; zapisanie w bx wskaźnika na pierwszy znak (wymagane do funkcji compare_number)
		mov bx,di
		call compare_number
		
		; sprawdzenie czy wprowadzono poprawny tekst
		; jeśli nie, to w al jest wartość 10
		cmp al,10
		jnz save_second_number
		; dla złego słowa wyświetlenie komunikatu błędu, wyczyszczenie bufora i przejście do początku
		call print_error_text
		jmp clean_and_return_to_beginning
	
	save_second_number:
		mov byte ptr ds:[second_number],al
	
	check_ending:
		; należy jeszcze sprawdzić czy nie podano żadnego słowa za dużo
		; zapisanie w BX wskaźnika do pierwszego znaku po słowie
		mov bx,di
		call omit_white_characters
		
		; jeśli znak wskazywany przez DI w buforze jest inny niż '$' to podano słowo za dużo
		cmp byte ptr ds:[di],'$'
		jz do_arythmetics
		; jeśli jest takie słowo to wyświetlany jest komunikat błędu, czyszczony bufor i program przechodzi do początku
		call print_error_text
		jmp clean_and_return_to_beginning

do_arythmetics:
	; w zależności od wartości zapisanej w operator_buffer wykonywane jest odpowiednie działanie
	; i wynik zapisywany jest w AL (AX), a w BL 0 gdy wynik jest dodatni lub 1 gdy jest ujemny
		
	; zapis do AH i AL wczytanych cyfr
	mov al,byte ptr ds:[first_number]
	mov ah,byte ptr ds:[second_number]
		
	add_numbers:
		; 11 zapisane w buforze operatora oznacza mnożenie
		cmp byte ptr ds:[operator_buffer],11
		jnz subtract_numbers		
		
		; dodanie i zapis wyniku w AL, najwyższy możliwy wynik i tak zmieści się na 8 bitach
		add al,ah
		; zerowanie AH, żeby funkcja czytająca liczbę i zamieniająca na napis mogła poprawnie porównywać
		xor ah,ah
		; w przypadku obsługiwanych liczb dla dodawania nie może zajść przeniesienie, BL jest zerowany
		xor bl,bl		
		jmp convert_result_to_digits
	
	subtract_numbers:
		; 12 zapisane w buforze operatora oznacza odejmowanie
		cmp byte ptr ds:[operator_buffer],12
		jnz multiply_numbers
		
		; odejmowanie i zapis wyniku w AL
		sub al,ah
		; czy nastąpiło przeniesienie
		jc set_minus_result
		; zerowanie AH, żeby funkcja czytająca liczbę i zamieniająca na napis mogła poprawnie porównywać
		xor ah,ah		
		
		; jeśli nie to zerowanie BL
		xor bl,bl
		jmp convert_result_to_digits
		
		set_minus_result:
			; jeśli nastąpiło przeniesienie to BL jest ustawiany na 1
			mov bl,1
			; zerowanie AH, żeby funkcja czytająca liczbę i zamieniająca na napis mogła poprawnie porównywać
			xor ah,ah
			jmp convert_result_to_digits
			
	multiply_numbers:
		; 13 zapisane w buforze operatora oznacza mnożenie, jak jest coś innego to wyrzucamy błąd
		cmp byte ptr ds:[operator_buffer],13
		jnz operator_error

		; mnożenie i zapis wyniku w AX
		mul ah
		; nie ma przeniesienia, zerowanie BL
		xor bl,bl
		jmp convert_result_to_digits

	operator_error:
		; na wypadek gdyby była inna wartość
		call print_error_text
		jmp clean_and_return_to_beginning
	
convert_result_to_digits:
		; wypisanie nowej linii i tekstu poprzedzającego wynik
		mov dx,offset end_line
		call print_text
		mov dx,offset result_text
		call print_text

		; sprawdzenie czy wynik jest ujemny
		cmp bl,1
		jne convert_positive_number
		
		; wypisanie tekstu minus
		mov dx,offset subtract_text
		call print_text
		
		; wypisanie spacji
		mov dx,offset space_text
		call print_text
		
		; zamiana liczby na przeciwną
		not al
		add al,1
		
	convert_positive_number:	
		; czy otrzymano 0
		cmp al,0
		jnz numbers_bigger_than_0
		; jeśli tak to wypisane zero
		mov dx,offset zero_text
		call print_text
		
		jmp end_printing_result
		
		numbers_bigger_than_0:
			; sprawdzenie czy wynik jest mniejszy od 10
			cmp al,10
			jae numbers_bigger_than_9
			
			; jeśli tak, to wypisana zostaje pojedyncza cyfra
			call print_less_significant_digit_text
			jmp end_printing_result
		
		numbers_bigger_than_9:
			; sprawdzenie czy wynik większy lub równy 20
			cmp al,20
			jae numbers_bigger_than_19
			
			; jeśli nie to wypisywana jest liczba z zakresu 10-19
			call print_10_to_19_number
			jmp end_printing_result
			
		numbers_bigger_than_19:
			; rozbicie liczby na cyfrę dziesiątek i jedności
			; do AL trafia cyfra dziesiątek, a do AH jedności
			mov cl,10
			div cl
			
			; wypisanie części dziesiętnej
			call print_more_significant_digit_text
			
			; jeśli cyfra jedności to 0, to nie ma potrzeby dalszego wypisywania czegokolwiek
			cmp ah,0
			jz end_printing_result
			
			; wypisanie spacji
			mov dx,offset space_text
			call print_text
			
			; żeby wypisać cyfrę jedności funkcja potrzebuje jej w AL
			mov al,ah
			call print_less_significant_digit_text
			jmp end_printing_result

end_printing_result:
	; na sam koniec wypisanie nowej linii
	mov dx,offset end_line
	call print_text
		
clean_and_return_to_beginning:
	; wyczyszczenie bufora tekstu, tekstu zachęty i powrót do początku
	call clear_text_buffer
	mov dx,offset end_line
	call print_text
	call print_entry_text
	jmp start_reading
			
end_program:
		; pusta linia
		mov dx,offset end_line
		call print_text
		
		; wyczyszczenie bufora klawiatury
		call clear_keyboard_buffer

		; wyjście z programu
		mov  ah,4ch			; instrukcja końca programu dla przerwania 21h
		mov  al,0			; kod wyjścia
		int  21h			; przerwanie 21h

; funkcje pomocnicze

print_welcome_text:			
		; wypisz tekst wstępny
		push dx
		
		mov dx,offset welcome_text_1
		call print_text
		mov dx,offset end_line
		call print_text
		mov dx,offset welcome_text_2
		call print_text
		mov dx,offset end_line
		call print_text
		mov dx,offset welcome_text_3
		call print_text
		mov dx,offset end_line
		call print_text
		
		pop dx		
		ret

print_entry_text:			
		; wypisz tekst zachęty do wpisania tekstu
		push dx
		mov  dx,offset entry_text
		call print_text
		pop dx
		
		ret

print_help:
		; wyświetla tekst pomocy
		; używany rejestr dx, więc odkładany jest na stos
		push dx
		
		; dwie puste linie na początek
		mov dx,offset end_line
		call print_text
		mov dx,offset end_line
		call print_text
		
		; pierwsza część tekstu
		mov dx,offset help_txt_1
		call print_text
		mov dx,offset end_line
		call print_text
		
		; druga
		mov dx,offset help_txt_2
		call print_text
		mov dx,offset end_line
		call print_text
		
		; trzecia
		mov dx,offset help_txt_3
		call print_text
		mov dx,offset end_line
		call print_text
		
		; wolna linia
		mov dx,offset end_line
		call print_text
		
		; czwarta
		mov dx,offset help_txt_4
		call print_text
		mov dx,offset end_line
		call print_text
		
		; wolna linia
		mov dx,offset end_line
		call print_text
		
		; piąta, na początku pojawia się tekst zachęty do wpisania danych
		mov dx,offset entry_text
		call print_text
		mov dx,offset help_txt_5
		call print_text
		mov dx,offset end_line
		call print_text
		
		; szósta, na początku pojawia się napis podający wyniku
		mov dx,offset result_text
		call print_text
		mov dx,offset help_txt_6
		call print_text
		mov dx,offset end_line
		call print_text
		
		pop dx
		ret

print_error_text:
		; wyświetlanie tekstu o błędnych danych wejściowych
		push dx
		
		; wolna linia na początek
		mov dx,offset end_line
		call print_text
		
		; tekst błędu i koniec linii
		mov  dx,offset error_text
		call print_text
		mov  dx,offset end_line
		call print_text
				
		pop dx
		ret

print_buffer_overflow_text:
		; wyświetlanie tekstu o przepełnieniu bufora
		push dx
		
		; wolna linia na początek
		mov dx,offset end_line
		call print_text
		
		; tekst błędu i koniec linii
		mov dx,offset buffer_overflow
		call print_text
		mov dx,offset end_line
		call print_text
		
		pop dx
		ret

print_text:					; parametr dx - offset napisu
		push ax				; AX jest tu modyfikowany, więc najpierw odkładany jest na stos
		mov  ax,seg data1	; wszystkie teksty maja ten sam segment
		mov  ds,ax			; segment trafia do ds, pośrednio przez ax
		mov  ah,9h			; instrukcja wypisania na ekran
		xor  al,al
		int  21h			; przerwanie 21h
		pop ax
		ret					; powrót

read_char:					; wczytuje jeden znak z klawiatury i zapisuje jego kod w al		
		begin_reading:		; etykieta, do której trzeba wrócić, jeśli odczytany scan code jest taki sam jak ten zapisany w pamięci
			in al,60h
			cmp al,byte ptr ds:[last_scan_code]
			jz begin_reading						; jeśli to ten sam znak co ostatnio, to wracamy do czytania
		
		mov byte ptr ds:[last_scan_code],al		; zapis nowego ostatniego scan code'u	
		ret

make_ascii:					; konwertuje kod klawisza zapisany w al na znak ASCII i zapisuje w ah
	; klawisz ESC - obsłużony w kodzie programu
	; kody od 2 do 0B - cyfry: 1,2,3,..,9,0
	numone:		
		cmp al,02h
		jnz numtwo
		mov ah,31h
		ret
	numtwo:		
		cmp al,03h
		jnz numthree
		mov ah,32h
		ret
	numthree:
		cmp al,04h
		jnz numfour
		mov ah,33h
		ret
	numfour:
		cmp al,05h
		jnz numfive
		mov ah,34h
		ret
	numfive:
		cmp al,06h
		jnz numsix
		mov ah,35h
		ret
	numsix:
		cmp al,07h
		jnz numseven
		mov ah,36h
		ret
	numseven:
		cmp al,08h
		jnz numeight
		mov ah,37h
		ret
	numeight:
		cmp al,09h
		jnz numnine
		mov ah,38h
		ret
	numnine:
		cmp al,0ah
		jnz numzero
		mov ah,39h
		ret
	numzero:
		cmp al,0bh
		jnz minus_sign
		mov ah,30h
		ret
		
	; kody 0C i 0D - znaki - i +
	minus_sign:
		cmp al,0ch
		jnz plus_sign
		mov ah,'-'
		ret
	plus_sign:
		cmp al,0dh
		jnz backspace
		mov ah,'+'
		ret
		
	; kody 0E i 0F - Backspace i TAB
	backspace:
		cmp al,0eh
		jnz tabulator
		mov ah,8h
		ret
	tabulator:
		cmp al,0fh
		jnz letq
		mov ah,20h
		ret
		
	; kolejne kody od 10 do 19 - litery Q,W,E,...,O,P
	letq:
		cmp al,10h
		jnz letw
		mov ah,'q'
		ret
	letw:
		cmp al,11h
		jnz lete
		mov ah,'w'
		ret
	lete:
		cmp al,12h
		jnz letr
		mov ah,'e'
		ret
	letr:
		cmp al,13h
		jnz lett
		mov ah,'r'
		ret
	lett:
		cmp al,14h
		jnz lety
		mov ah,'t'
		ret
	lety:
		cmp al,15h
		jnz letu
		mov ah,'y'
		ret
	letu:
		cmp al,16h
		jnz leti
		mov ah,'u'
		ret
	leti:
		cmp al,17h
		jnz leto
		mov ah,'i'
		ret
	leto:
		cmp al,18h
		jnz letp
		mov ah,'o'
		ret
	letp:
		cmp al,19h
		jnz leta
		mov ah,'p'
		ret
	
	; kody od 1E do 26 - litery od A do L
	leta:
		cmp al,1eh
		jnz lets
		mov ah,'a'
		ret
	lets:
		cmp al,1fh
		jnz letd
		mov ah,'s'
		ret
	letd:
		cmp al,20h
		jnz letf
		mov ah,'d'
		ret
	letf:
		cmp al,21h
		jnz letg
		mov ah,'f'
		ret
	letg:
		cmp al,22h
		jnz leth
		mov ah,'g'
		ret
	leth:
		cmp al,23h
		jnz letj
		mov ah,'h'
		ret
	letj:
		cmp al,24h
		jnz letk
		mov ah,'j'
		ret
	letk:
		cmp al,25h
		jnz letl
		mov ah,'k'
		ret
	letl:
		cmp al,26h
		jnz letz
		mov ah,'l'
		ret
		
	; kody od 2C do 32 - ostatni rząd liter na klawiaturze: od Z do M
	letz:
		cmp al,2ch
		jnz letx
		mov ah,'z'
		ret
	letx:
		cmp al,2dh
		jnz letc
		mov ah,'x'
		ret
	letc:
		cmp al,2eh
		jnz letv
		mov ah,'c'
		ret
	letv:
		cmp al,2fh
		jnz letb
		mov ah,'v'
		ret
	letb:
		cmp al,30h
		jnz letn
		mov ah,'b'
		ret
	letn:
		cmp al,31h
		jnz letm
		mov ah,'n'
		ret
	letm:
		cmp al,32h
		jnz space_key
		mov ah,'m'
		ret
	
	; kod 39 - spacja
	space_key:
		cmp al,39h
		jnz other_key
		mov ah,20h
		ret
		
	; reszta klawiszy jest nieistotna w tym programie
	other_key:
		mov ah,'$'
		ret
		
clear_keyboard_buffer:		; czyści bufor klawiatury, potrzebne żeby po wyjściu nic nie zostało w wierszu poleceń
		xor  ax,ax			; al jest wcześniej używane, wiec zerowany jest cały ax
		mov  ah,0ch			
		int  21h			
		ret

print_backspace:					; funkcja do poprawnego wypisania Backspace'a
		cmp di,0					; di = 0 oznacza pusty bufor i nie ma co kasować
		jz end_print_backspace		

		mov  byte ptr ds:[char_buffer],8h
		mov  dx, offset char_buffer	; przy wywołaniu funkcji w buforze dla znaku jest kod klawisza Backspace
		call print_text 			; wypisanie Backspace cofa kursor o jedną pozycję w lewo
		
		; żeby usunąć poprzedni znak wypisana zostanie spacja
		mov  byte ptr ds:[char_buffer],20h	
		mov  dx, offset char_buffer
		call print_text
		
		; oraz kolejny znak Backspace żeby wrócić do poprzedniej pozycji kursora
		mov byte ptr ds:[char_buffer],8h	
		mov dx, offset char_buffer
		call print_text
		
		; jeśli w di jest wartość > 0 to jest obniżana
		cmp di,0
		jz end_print_backspace			
		
		dec di
		
		; kasowanie znak z pamięci
		mov byte ptr ds:[buffer + di],'$'
		
		end_print_backspace:
		ret

clear_text_buffer:
		; czyści bufor zapisanych znaków
		
		; zapisanie w CX długości wczytanego wcześniej ciągu znaków
		mov cx,word ptr ds:[read_characters]
		
		; ustawienie w ES wskaźnika segmentu danych
		mov ax,seg data1
		mov es,ax
		; ustawienie w DI offsetu bufora
		mov di,offset buffer
		
		; zapisanie w AL znaku do wypełnienia bufora
		mov al,'$'
		
		; ustawienie DF na 0 i wypełnienie bufora
		cld
		rep stosb
		
		; wyzerowanie długości słowa zapisanej w pamięci
		mov word ptr ds:[read_characters],0
		
		ret
		
read_to_buffer:
		; zerowanie DI - będzie on pokazywać pozycję do zapisu kolejnego znaku
		xor di,di
	start_reading_to_buffer:
		; czytanie linijki od użytkownika
		call read_char
		
		; sprawdzenie czy nie za duży scan code
		cmp al,3ah
		ja start_reading_to_buffer
		
		; czy wciśnięto ESC
		cmp al,01h
		jnz buffer_read_backspace
		pop ax			; żeby na stosie nie został adres powrotu
		jz end_program	; jeśli tak, to koniec wykonywania programu
		
		; czy wciśnięto Backspace
		buffer_read_backspace:
			cmp al,0eh
			jnz buffer_read_help
			call print_backspace
			jmp start_reading_to_buffer
		
		; czy wciśnięto klawisz pomocy
		buffer_read_help:
			cmp al,35h
			jnz buffer_read_enter
			call print_help
			pop ax			; żeby na stosie nie został adres powrotu
			; zapisanie do pamięci długości wczytanego ciagu znaków
			mov word ptr ds:[read_characters],di
			jmp clean_and_return_to_beginning	
		
		; czy wciśnięto Enter
		buffer_read_enter:
			cmp al,1ch
			jnz check_buffer_size	
			; zapisanie do bufora na końcu spacji, żeby poprawnie można było porównywać ostatnie słowo
			mov byte ptr ds:[buffer + di],' '
			; zapisanie do pamięci długości wczytanego ciagu znaków
			mov word ptr ds:[read_characters],di
			ret

		check_buffer_size:
			; sprawdzenie czy nie przekroczono rozmiaru bufora
			cmp di,255
			jnz save_char_to_buffer
			call print_buffer_overflow_text
			pop ax			; żeby na stosie nie został adres powrotu
			; zapisanie do pamięci długości wczytanego ciagu znaków
			mov word ptr ds:[read_characters],di
			jmp clean_and_return_to_beginning
		
		save_char_to_buffer:
			; zamiana scan code'u na kod ASCII, jeśli wciśnięto nieistotny klawisz dający $
			; to powrót do początku czytania
			call make_ascii
			cmp ah,'$'		
			jz start_reading_to_buffer
		
			; jeśli wczytano obsługiwany znak
			mov byte ptr ds:[char_buffer],ah	; zapis znaku do bufora znakowego
			mov byte ptr ds:[buffer + di],ah	; zapis znaku do bufora tekstu
			inc di								; zwiększenie DI (pokazuje następną wolną pozycję w buforze)
			mov dx,offset char_buffer			; wypisanie na ekran wprowadzonego znaku
			call print_text
			call clear_keyboard_buffer			; wyczyszczenie bufora klawiatury
		
		; kontynuacja czytania
		jmp start_reading_to_buffer						

omit_white_characters:
		; na wejściu w bx powinien być offset początku czytania
		; na wyjściu w di pozycja znalezionego słowa
		mov ax,ds				; wskaźnik segmentu trafia do AX
		mov es,ax				; żeby zostać wpisanym do ES
		mov di,bx				; ES:DI pokazuje na bufor znakowy
		mov al, ' '				; w AL trzymana wartość porównywana (spacja)
		mov cx,255				; w CX rozmiar bufora
		
		cld						; ustawienie znacznika DF na 0
		repz scasb				; dopóki kolejne znaki w buforze to spacje to pomijamy
		
		dec di					; po znalezieniu pierwszego znaku nie będącego spacją di pokazuje na następny znak
								; więc trzeba obniżyć jego wartość o 1
		ret						; tutaj w DI jest zapisany offset znalezionego następnego słowa

prepare_comparison:
		; przygotowanie rejestrów do porównywania czy wprowadzono poprawny ciąg znaków
		mov cx,255 				; długość bufora		
		mov di,bx				; zapisanie offsetu bufora tekstu do DI
		ret

compare_number:
		; funkcja sprawdza czy podany napis reprezentuje cyfrę		
		; wejście: w bx offset pierwszego znaku
		; wyjście: do al trafia wynik liczbowy,
		; 		   a di wskazuje na pierwszy znak po badanym słowie
		
		; ustawienie w ES segmentu danych
		mov ax,seg data1		
		mov es,ax
		
		; przygotowanie pozostałych rejestrów
		call prepare_comparison		
				
		check_zero:
			mov si,offset zero_text			
			repz cmpsb
			
			; po znalezieniu pierwszego niepasującego znaku rejestr SI wskazuje na następny bajt po nim
			; aby poprawnie porównać, trzeba obniżyć jego wartość
			dec si
			
			; jeśli SI pokazuje na '$' którym kończy się słowo "zero" w pamięci, to jest poprawnie
			cmp byte ptr ds:[si],'$'
			jnz not_zero
			
			; jednocześnie w buforze na następnym miejscu musi być biały znak
			; DI zmniejszane z takiego samego powodu jak wyżej dla SI
			dec di
			cmp byte ptr ds:[di],' '
			jnz not_zero
			
			mov al,0
			ret	
			
		not_zero:
			; ponowne przygotowanie rejestrów
			call prepare_comparison
		
		check_one:
			; metoda porównania j.w. dla zera
			mov si,offset one_text
			repz cmpsb
			
			dec si			
			cmp byte ptr ds:[si],'$'
			jnz not_one
			
			dec di
			cmp byte ptr ds:[di],' '
			jnz not_one
			
			mov al,1
			ret
			
		not_one:
			; ponowne przygotowanie rejestrów
			call prepare_comparison
		
		check_two:
			; porównanie jak dla zera
			mov si,offset two_text
			repz cmpsb
			
			dec si
			cmp byte ptr ds:[si],'$'
			jnz not_two
			
			dec di
			cmp byte ptr ds:[di],' '
			jnz not_two
			
			mov al,2
			ret
			
		not_two:
			; ponowne przygotowanie rejestrów
			call prepare_comparison
			
		check_three:
			; porównanie jak dla zera
			mov si,offset three_text
			repz cmpsb
			
			dec si
			cmp byte ptr ds:[si],'$'
			jnz not_three
			
			dec di
			cmp byte ptr ds:[di],' '
			jnz not_three
			
			mov al,3
			ret			
			
		not_three:
			; ponowne przygotowanie rejestrów
			call prepare_comparison
		
		check_four:
			; porównanie jak dla zera
			mov si,offset four_text
			repz cmpsb
			
			dec si
			cmp byte ptr ds:[si],'$'
			jnz not_four
			
			dec di
			cmp byte ptr ds:[di],' '
			jnz not_four
			
			mov al,4
			ret			
			
		not_four:
			; ponowne przygotowanie rejestrów
			call prepare_comparison
		
		check_five:
			; porównanie jak dla zera
			mov si,offset five_text
			repz cmpsb
			
			dec si
			cmp byte ptr ds:[si],'$'
			jnz not_five
			
			dec di
			cmp byte ptr ds:[di],' '
			jnz not_five
			
			mov al,5
			ret			
			
		not_five:
			; ponowne przygotowanie rejestrów
			call prepare_comparison
		
		check_six:
			; porównanie jak dla zera
			mov si,offset six_text
			repz cmpsb
			
			dec si
			cmp byte ptr ds:[si],'$'
			jnz not_six
			
			dec di
			cmp byte ptr ds:[di],' '
			jnz not_six
			
			mov al,6
			ret	
			
		not_six:
			; ponowne przygotowanie rejestrów
			call prepare_comparison
		
		check_seven:
			; porównanie jak dla zera
			mov si,offset seven_text
			repz cmpsb
			
			dec si
			cmp byte ptr ds:[si],'$'
			jnz not_seven
			
			dec di
			cmp byte ptr ds:[di],' '
			jnz not_seven
			
			mov al,7
			ret	
			
		not_seven:
			; ponowne przygotowanie rejestrów
			call prepare_comparison
		
		check_eight:
			; porównanie jak dla zera
			mov si,offset eight_text
			repz cmpsb
			
			dec si
			cmp byte ptr ds:[si],'$'
			jnz not_eight
			
			dec di
			cmp byte ptr ds:[di],' '
			jnz not_eight
			
			mov al,8
			ret	
			
		not_eight:
			; ponowne przygotowanie rejestrów
			call prepare_comparison
		
		check_nine:
			; porównanie jak dla zera
			mov si,offset nine_text
			repz cmpsb
			
			dec si
			cmp byte ptr ds:[si],'$'
			jnz not_nine
			
			dec di
			cmp byte ptr ds:[di],' '
			jnz not_nine
			
			mov al,9
			ret
			
		not_nine:
			; nie dopasowano niczego - zapis wartości 10 do al
			mov al,10		    
			ret

compare_operator:
		; sprawdzenie czy podano poprawny operator, działanie jak compare_number
		; wejście: w bx offset pierwszego znaku
		; wyjście: do al trafia wynik liczbowy - 11 dla plusa, 12 dla minusa, 13 dla mnożenia,
		; 		   a di wskazuje na pierwszy znak po badanym słowie
		
		; ustawienie w ES segmentu danych
		mov ax,seg data1		
		mov es,ax
		
		; przygotowanie pozostałych rejestrów
		call prepare_comparison	

		check_plus:
			; porównanie analogiczne jak dla cyfry w compare_number
			mov si,offset add_text
			repz cmpsb
			
			dec si
			cmp byte ptr ds:[si],'$'
			jnz not_plus
			
			dec di
			cmp byte ptr ds:[di],' '
			jnz not_plus
			
			mov al,11
			ret
		
		not_plus:
			; ponowne przygotowanie rejestrów
			call prepare_comparison
		
		check_minus:
			; porównanie analogiczne jak dla cyfry w compare_number
			mov si,offset subtract_text
			repz cmpsb
			
			dec si
			cmp byte ptr ds:[si],'$'
			jnz not_minus
			
			dec di
			cmp byte ptr ds:[di],' '
			jnz not_minus
			
			mov al,12
			ret
			
		not_minus:
			; ponowne przygotowanie rejestrów
			call prepare_comparison
		
		check_multiply:
			; porównanie analogiczne jak dla cyfry w compare_number
			mov si,offset multiply_text
			repz cmpsb
			
			dec si
			cmp byte ptr ds:[si],'$'
			jnz not_multiply
			
			dec di
			cmp byte ptr ds:[di],' '
			jnz not_multiply
			
			mov al,13
			ret
		
		not_multiply:
			; nie dopasowano niczego - zapis 10 do al
			mov al,10
			ret

print_less_significant_digit_text:
	; wypisuje cyfrę jedności w postaci tekstowej
	; cyfra powinna być zapisana w AL
	
	; zero obsłużone w głównej części programu
	print_one:
		; wypisanie jedynki
		cmp al,1
		jnz print_two
	
		mov dx,offset one_text
		call print_text
		ret
		
	print_two:
		; wypisanie dwójki
		cmp al,2
		jnz print_three
		
		mov dx,offset two_text
		call print_text
		ret
		
	print_three:
		; wypisanie trójki
		cmp al,3
		jnz print_four
		
		mov dx,offset three_text
		call print_text
		ret
		
	print_four:
		; wypisanie czwórki
		cmp al,4
		jnz print_five
		
		mov dx,offset four_text
		call print_text
		ret
		
	print_five:
		; wypisanie piątki
		cmp al,5
		jnz print_six
		
		mov dx,offset five_text
		call print_text
		ret
		
	print_six:
		; wypisanie szóstki
		cmp al,6
		jnz print_seven
		
		mov dx,offset six_text
		call print_text
		ret
		
	print_seven:
		; wypisanie siódemki
		cmp al,7
		jnz print_eight
		
		mov dx,offset seven_text
		call print_text
		ret
		
	print_eight:
		; wypisanie ósemki
		cmp al,8
		jnz print_nine
		
		mov dx,offset eight_text
		call print_text
		ret
	
	print_nine:
		; wypisanie dziewiątki
		cmp al,9
		jnz print_nothing_less_sign
		
		mov dx,offset nine_text
		call print_text
		
	print_nothing_less_sign:
		ret

print_10_to_19_number:
	; wypisuje liczby z zakresu 10 do 19
	; liczba powinna być na wejściu zapisana w AL
	print_ten:
		; wypisanie dziesięciu
		cmp al,10
		jnz print_eleven
		
		mov dx,offset ten_text
		call print_text
		ret
		
	print_eleven:
		; wypisanie jedenastu
		cmp al,11
		jnz print_twelve
		
		mov dx,offset eleven_text
		call print_text
		ret
	
	print_twelve:
		; wypisanie dwunastu
		cmp al,12
		jnz print_thirteen
		
		mov dx,offset twelve_text
		call print_text
		ret
	
	print_thirteen:
		; wypisanie trzynastu
		cmp al,13
		jnz print_fourteen
		
		mov dx,offset thirteen_text
		call print_text
		ret
	
	print_fourteen:
		; wypisanie czternastu
		cmp al,14
		jnz print_fifteen
		
		mov dx,offset fourteen_text
		call print_text
		ret
	
	print_fifteen:
		; wypisanie piętnastu
		cmp al,15
		jnz print_sixteen
		
		mov dx,offset fifteen_text
		call print_text
		ret
	
	print_sixteen:
		; wypisanie szesnastu
		cmp al,16
		jnz print_seventeen
		
		mov dx,offset sixteen_text
		call print_text
		ret
	
	print_seventeen:
		; wypisanie siedemnastu
		cmp al,17
		jnz print_eighteen
		
		mov dx,offset seventeen_text
		call print_text
		ret
	
	print_eighteen:
		; wypisanie osiemnastu
		cmp al,18
		jnz print_nineteen
		
		mov dx,offset eighteen_text
		call print_text
		ret
	
	print_nineteen:
		; wypisanie dziewiętnastu
		cmp al,19
		jnz print_nothing_10_to_19
		
		mov dx,offset nineteen_text
		call print_text
	
	print_nothing_10_to_19:
		ret

print_more_significant_digit_text:
	; wypisuje część dziesiętną liczby
	; cyfra dziesiątek na wejściu musi być zapisana w AL
	
	print_twenty:
		; wypisanie dwudziestu
		cmp al,2
		jnz print_thirty
		
		mov dx,offset twenty_text
		call print_text
		ret
		
	print_thirty:
		; wypisanie trzydziestu
		cmp al,3
		jnz print_forty
		
		mov dx,offset thirty_text
		call print_text
		ret
	
	print_forty:
		; wypisanie czterdziestu
		cmp al,4
		jnz print_fifty
		
		mov dx,offset forty_text
		call print_text
		ret
	
	print_fifty:
		; wypisanie pięćdziesięciu
		cmp al,5
		jnz print_sixty
		
		mov dx,offset fifty_text
		call print_text
		ret
	
	print_sixty:
		; wypisanie sześćdziesięciu
		cmp al,6
		jnz print_seventy
		
		mov dx,offset sixty_text
		call print_text
		ret
	
	print_seventy:
		; wypisanie siedemdziesięciu
		cmp al,7
		jnz print_eighty
		
		mov dx,offset seventy_text
		call print_text
		ret
	
	print_eighty:
		; wypisanie osiemdziesięciu
		cmp al,8
		jnz print_ninety
		
		mov dx,offset eighty_text
		call print_text
		ret
	
	print_ninety:
		; wypisanie dziewięćdziesięciu
		cmp al,9
		jnz print_nothing_more_sign
		
		mov dx,offset ninety_text
		call print_text
	
	print_nothing_more_sign:
		ret
			
code1 ends

stack1 segment stack		; segment stosu

		dw 400 dup(?)		; rezerwacja 400 słów pamięci
	ws1	dw ?				; wierzcholek stosu
	
stack1 ends

end init_stack				; koniec programu i wywołanie pierwszej instrukcji