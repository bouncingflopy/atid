.386
IDEAL
MODEL small
STACK 100h
DATASEG

; -------------------------------------------------------------------------------------
; -------------------------------------------------------------------------------------
; the dots array is sorted in the following order: x position, y position, color
dot_amount dw 0
dot_size dw 1
dots dw 100h dup (?, ?, ?), 321
dots_prev dw 100h dup (?, ?, ?), 321
dots_wall_prev dw 100h dup (?, ?, ?), 321

; the sticks array is sorted in the following order: first dot, second dot, color
stick_amount dw 0
stick_size dw 1
sticks dw 100h dup (?, ?, ?), 0
sticks_length dw 100h dup (?, ?, ?), 0

; colors
dot_color dw 2
selected_color dw 7
locked_color dw 56
stick_color dw 18

; mode: 0 -> sandbox simulation setup, 1 -> run simulation
mode dw 0
stick_handle dw 0
selected dw 0
saved_color dw 0
left dw 0
left_prev dw 0
right dw 0
right_prev dw 0

; fpu
fpu dd ?

; nuclear (no clear) mode
nuclear dw 0
; -------------------------------------------------------------------------------------
; -------------------------------------------------------------------------------------

CODESEG

; input: none
; output: none
proc delay
	push cx
	
	mov cx, 50
	outer_loop:
		push cx
		
		mov cx, 0FFFFh
		inner_loop:
		loop inner_loop
		
		pop cx
	loop outer_loop
	
	pop cx
	ret
endp delay

; input: none
; output: none
proc delay_physics
	push cx
	
	mov cx, 40
	outer_loop_physics:
		push cx
		
		mov cx, 0FFFFh
		inner_loop_p:
		loop inner_loop_p
		
		pop cx
	loop outer_loop_physics
	
	pop cx
	ret
endp delay_physics

; input: x position, y position, color
proc draw_dot
	push bp
	mov bp, sp
	push ax
	push cx
	push dx
	push di
	
	; get screen position - y*320+x
	mov ax, [bp+6]
	mov cx, 320
	xor dx, dx
	mul cx
	add ax, [bp+8]
	mov di, ax
	
	; get color and display color
	mov ax, [bp+4]
	mov [es:di], al
	
	pop di
	pop dx
	pop cx
	pop ax
	pop bp
	ret 6
endp draw_dot

; input: array start location, element in array
; output: beginning of element data in array
proc array_access
	push bp
	mov bp, sp
	push ax
	push cx
	
	; get starting position of element information in array
	mov ax, [bp+4]
	dec ax
	mov cx, 6
	mul cl
	add ax, [bp+6]
	mov [bp+6], ax
	
	pop cx
	pop ax
	pop bp
	ret 2
endp array_access

; input: dots start, dot position in array
; output: none
proc display_dot
	push bp
	mov bp, sp
	push ax
	push bx
	push cx
	
	push [word ptr bp+6]
	push [word ptr bp+4]
	call array_access
	pop bx
	
	push [word ptr bx]
	push [word ptr bx+2]
	push [word ptr bx+4]
	call draw_dot
	
	pop cx
	pop bx
	pop ax
	pop bp
	ret 4
endp display_dot

; input: dots start, dot position in array, size of square
; output: none
proc display_square
	push bp
	mov bp, sp
	push ax
	push bx
	push cx
	push dx
	push di
	
	push [word ptr bp+8]
	push [word ptr bp+6]
	call array_access
	pop bx
	
	; check if dot isnt too close to border
		mov ax, [bx]
		cmp ax, [bp+4]
		jl cant_display
		mov cx, 320
		sub cx, [bp+4]
		cmp ax, cx
		jg cant_display
		
		mov dx, [bx+2]
		cmp dx, [bp+4]
		mov cx, 320
		sub cx, [bp+4]
		cmp dx, cx
		jg cant_display
	
	; find top-left corner
	sub ax, [bp+4]
	sub dx, [bp+4]
	
	mov bx, [bx+4]
	mov cx, [bp+4]
	shl cx, 1
	inc cx
	column:
		push ax
		push cx
		
		mov cx, [bp+4]
		shl cx, 1
		inc cx
		row:
			push ax
			push dx
			push bx
			call draw_dot
			
			inc ax
		loop row
		
		pop cx
		pop ax
	inc dx
	loop column
	
	cant_display:
	pop di
	pop dx
	pop cx
	pop bx
	pop ax
	pop bp
	ret 6
endp display_square

; the naive line drawing algorithem, can be fouund in wikipedia
; input: dx, dy, y or x mode, x1, y1, x2, y2, color
; outupt: none
proc naive_algo
	push bp
	mov bp, sp
	push ax
	push bx
	push cx
	push dx
	push di
	push si
	
	; get xy mode
	mov bx, [bp+14]
	
	; dx = x1 − x2
		mov di, [bp+18]
	
	; dy = y1 − y2
		mov si, [bp+16]
	
	; for x from x1 to x2 do
	mov cx, [bp+12]
	dec cx
	naive_algo_loop:
		inc cx
		
		; y = yLow + dy × (x − xLow) / dx
		mov ax, cx
		sub ax, [bp+12]
		
		xor dx, dx
		mul si
		div di
		
		; compare y's
			mov dx, [bp+10]
			cmp dx, [bp+6]
			jb naive_y_normal
			
			mov dx, [bp+10]
			sub dx, ax
			mov ax, dx
			jmp after_naive_y
			
			naive_y_normal:
			add ax, [bp+10]
			after_naive_y:
			
		; plot(x, y)
			cmp bx, 0
			jne yx
				push cx
				push ax
			jmp after_mode
			
			yx:
				push ax
				push cx
			
			after_mode:
			push [word ptr bp+4]
			call draw_dot
			
		cmp cx, [bp+8]
		jne naive_algo_loop
	
	pop si
	pop di
	pop dx
	pop cx
	pop bx
	pop ax
	pop bp
	ret 16
endp naive_algo

; input: x1, y1, x2, y2, color
; output: none
proc naive_algo_setup
	push bp
	mov bp, sp
	push ax
	push di
	push si
	
	mov ax, [bp+12]
	cmp ax, [bp+8]
	jne not_equal
	mov ax, [bp+10]
	cmp ax, [bp+6]
	jne not_equal
	
	jmp naive_algo_setup_end
	not_equal:
	
	; dx
		mov ax, [bp+12]
		cmp ax, [bp+8]
		jb dx_else
		
		mov di, [bp+12]
		sub di, [bp+8]
		jmp dx_after
		
		dx_else:
		mov di, [bp+8]
		sub di, [bp+12]
		dx_after:
	
	; dy
		mov ax, [bp+10]
		cmp ax, [bp+6]
		jb dy_else
		
		mov si, [bp+10]
		sub si, [bp+6]
		jmp dy_after
		
		dy_else:
		mov si, [bp+6]
		sub si, [bp+10]
		dy_after:
	
	; ------------
	; 12 - Ax
	; 10 - Ay
	; 8 - Bx
	; 6 - By
	; di - Dx
	; si - Dy
	; 4 - color
	; ------------
	
	
	; if di > si:
		; if 12 > 8:
			; 8, 6, 12, 10
		; else:
			; 12, 10, 8, 6
	; else:
		; if 10 > 6
			; 6, 8, 10, 12
		; else:
			; 10, 12, 6, 8
	
	cmp di, si
	jb main_else
		
		push di
		push si
		mov ax, 0
		push ax
		mov ax, [bp+12]
		cmp ax, [bp+8]
		jb main_x_else
		
			push [word ptr bp+8]
			push [word ptr bp+6]
			push [word ptr bp+12]
			push [word ptr bp+10]
			push [word ptr bp+4]
			call naive_algo
		jmp naive_algo_setup_end
		
		main_x_else:
			push [word ptr bp+12]
			push [word ptr bp+10]
			push [word ptr bp+8]
			push [word ptr bp+6]
			push [word ptr bp+4]
			call naive_algo
	jmp naive_algo_setup_end
	
	main_else:
		
		push si
		push di
		mov ax, 1
		push ax
		mov ax, [bp+10]
		cmp ax, [bp+6]
		jb main_y_else
		
			push [word ptr bp+6]
			push [word ptr bp+8]
			push [word ptr bp+10]
			push [word ptr bp+12]
			push [word ptr bp+4]
			call naive_algo
		jmp naive_algo_setup_end
		
		main_y_else:
			push [word ptr bp+10]
			push [word ptr bp+12]
			push [word ptr bp+6]
			push [word ptr bp+8]
			push [word ptr bp+4]
			call naive_algo
	
	naive_algo_setup_end:
	pop si
	pop di
	pop ax
	pop bp
	ret 10
endp naive_algo_setup

; input: sticks start, stick position in array, dots start
; output: none
proc display_stick
	push bp
	mov bp, sp
	push ax
	push bx
	push cx
	push dx
	push di
	push si
	
	push [word ptr bp+8]
	push [word ptr bp+6]
	call array_access
	pop bx
	
	; get first dot's x and y positions
	push bx
	mov bx, [bx]
	push [word ptr bp+4]
	push bx
	call array_access
	pop bx
	mov cx, [bx]
	mov dx, [bx+2]
	pop bx
	
	; get second dot's x and y positions
	add bx, 2
	push bx
	mov bx, [bx]
	push [word ptr bp+4]
	push bx
	call array_access
	pop bx
	mov di, [bx]
	mov si, [bx+2]
	pop bx
	
	; get stick color
	add bx, 2
	mov ax, [bx]
	
	; ------------
	; cx - Ax
	; dx - Ay
	; di - Bx
	; si - By
	; ax - color
	; ------------
	
	push cx
	push dx
	push di
	push si
	push ax
	call naive_algo_setup
	
	pop si
	pop di
	pop dx
	pop cx
	pop bx
	pop ax
	pop bp
	ret 6
endp display_stick

; input: new element's first property, new element's second property, new element's color, array start, array amount location in memory
; output: output
proc array_add
	push bp
	mov bp, sp
	push ax
	push bx
	
	mov bx, [bp+4]
	mov ax, [bx]
	inc ax
	mov [bx], ax
	
	push [word ptr bp+6]
	push ax
	call array_access
	pop bx
	
	mov ax, [bp+12]
	mov [bx], ax
	mov ax, [bp+10]
	mov [bx+2], ax
	mov ax, [bp+8]
	mov [bx+4], ax
	
	pop bx
	pop ax
	pop bp
	ret 10
endp array_add

; input: dot array start, x lookup, y lookup
; output: start of element in memory; 0 if no element is selected
proc search_dots_by_position
	push bp
	mov bp, sp
	push ax
	push bx
	push cx
	push dx
	push di
	
	; set default value for output
	mov dx, 0
	
	mov bx, [bp+8]
	sub bx, 6
	search_loop:
	add bx, 6
	
	mov cx, [bp+6]
	sub cx, 2
	search_x_loop:
		inc cx
		
		cmp cx, [bx]
		jne search_x_loop_end
			push cx
			
			mov cx, [bp+4]
			sub cx, 2
			search_y_loop:
			inc cx
			
			cmp cx, [bx+2]
			jne search_y_loop_end
				
				mov ax, bx
				sub ax, [bp+8]
				add ax, 6
				xor dx, dx
				mov di, 6
				div di
				mov dx, ax
				
				pop cx
				jmp end_search
			
			search_y_loop_end:
			cmp cx, [bp+4]
			jbe search_y_loop
		
		pop cx
		search_x_loop_end:
		cmp cx, [bp+6]
		jbe search_x_loop
	
	mov ax, 321
	cmp [bx], ax
	jne search_loop
	
	end_search:
	cmp dx, 0
	je end_end_search
	
	end_end_search:
	mov [bp+8], dx
	
	pop di
	pop dx
	pop cx
	pop bx
	pop ax
	pop bp
	ret 4
endp search_dots_by_position

; input: prev dots start location in memory, dots start location in memory, dot's element number in array
; output: 1 - dot changed; 0 - dot didn't change
proc check_dot_change
	push bp
	mov bp, sp
	push ax
	push bx
	push cx
	push dx
	push di
	
	mov ax, 0
	
	push [word ptr bp+8]
	push [word ptr bp+4]
	call array_access
	pop bx
	
	push [word ptr bp+6]
	push [word ptr bp+4]
	call array_access
	pop di
	
	mov cx, 3
	check_dot_change_loop:
		mov dx, [bx]
		cmp dx, [di]
		jne dot_changed
		add bx, 2
		add di, 2
	loop check_dot_change_loop
	jmp check_dot_change_exit
	
	dot_changed:
	mov ax, 1
	
	check_dot_change_exit:
	mov [bp+8], ax
	pop di
	pop dx
	pop cx
	pop bx
	pop ax
	pop bp
	ret 4
endp check_dot_change

; input: none
; output: none
proc clear
	push ax
	push cx
	push di
	
	mov ax, 0
	
	mov cx, 320*200
	clear_loop:
		mov di, cx
		mov [es:di], ax
	loop clear_loop
	
	pop di
	pop cx
	pop ax
	ret
endp clear

; input: wall dots start in memory, prev dots start in memory, dots start in memory, dots amount, dots size, sticks start in memory, stick amount
; ouput: none
proc render
	push bp
	mov bp, sp
	push bx
	push cx
	push di
	
	mov cx, [bp+4]
	render_sticks:
		cmp cx, 0
		je render_sticks_after
		
		push [word ptr bp+6]
		push cx
		call array_access
		pop bx
		
		push [word ptr bp+6]
		push cx
		push [word ptr bp+12]
		call display_stick
		
		dec cx
	jmp render_sticks
	render_sticks_after:
	
	mov cx, [bp+10]
	render_dots:
		cmp cx, 0
		je render_dots_after
		
		push [word ptr bp+12]
		push cx
		push [word ptr bp+8]
		call display_square
		
		dec cx
	jmp render_dots
	render_dots_after:
	
	pop di
	pop cx
	pop bx
	pop bp
	ret 14
endp render

; input: wall dots start in memory, dots element number in memory, point's x, point's y, point's beforeUpdate x, point's beforeUpdate y, prev point's position in memory
; output: edited point's x, edited point's y, edited point's beforeUpdate x, edited point's beforeUpdate y
proc wall
	push bp
	mov bp, sp
	push ax
	push bx
	push cx
	push dx
	push di
	push si
	
	mov ax, [bp+12]
	mov dx, [bp+10]
	mov di, [bp+8]
	mov si, [bp+6]
	mov bx, [bp+4]
	
	; copy to wall prev
		push bx
		push ax
		
		mov bx, [bp+16]
		push bx
		mov bx, [bp+14]
		push bx
		call array_access
		pop bx
		mov ax, [bp+8]
		mov [bx], ax
		mov ax, [bp+6]
		mov [bx+2], ax
		mov [word ptr bx+4], 0
		
		pop ax
		pop bx
	
	wall_x_left:
		mov cx, 2
		cmp ax, cx
		jae wall_x_right
		
		mov ax, 2
		mov cx, ax
		sub cx, [bx]
		add di, cx
	wall_x_right:
		mov cx, 318
		cmp ax, cx
		jbe wall_y_up
		
		mov ax, 318
		mov cx, ax
		sub cx, [bx]
		add di, cx
	wall_y_up:
		mov cx, 2
		cmp dx, cx
		jae wall_y_down
		
		mov dx, 2
		mov cx, dx
		sub cx, [bx+2]
		add si, cx
	wall_y_down:
		mov cx, 198
		cmp dx, cx
		jbe wall_exit
		
		mov dx, 198
		mov cx, dx
		sub cx, [bx+2]
		add si, cx
	
	wall_exit:
	mov [bp+16], ax
	mov [bp+14], dx
	mov [bp+12], di
	mov [bp+10], si
	
	pop si
	pop di
	pop dx
	pop cx
	pop bx
	pop ax
	pop bp
	ret 6
endp wall

; input: locked color, dots wall start in memory, dots start in memory, previous dots start in memory, dots amount
; output: none
proc physics_dots
	push bp
	mov bp, sp
	push ax
	push bx
	push cx
	push dx
	push di
	push si
	
	mov cx, [bp+4]
	physics_dots_loop:
		push cx
		
		push [word ptr bp+8]
		push cx
		call array_access
		pop bx
		
		mov ax, [bp+12]
		cmp [bx+4], ax
		je physics_dots_loop_end
		push bx
		
		mov ax, [bx]
		mov dx, [bx+2]
		mov di, ax
		mov si, dx
		
		push [word ptr bp+6]
		push cx
		call array_access
		pop bx
		
		; ------------
		; ax - pointX
		; dx - pointY
		; di - startPointX
		; si - startPointY
		; bx - prevPoint in memory
		; ------------
		
		sal ax, 1
		sub ax, [bx]
		sal dx, 1
		sub dx, [bx+2]
		; gravity
		add dx, 1
		
		push [word ptr bp+10]
		push cx
		push ax
		push dx
		push di
		push si
		push bx
		call wall
		pop si
		pop di
		pop dx
		pop ax
		
		mov [bx], di
		mov [bx+2], si
		
		pop bx
		mov [bx], ax
		mov [bx+2], dx
		
		physics_dots_loop_end:
		pop cx
	loop physics_dots_loop
	
	pop si
	pop di
	pop dx
	pop cx
	pop bx
	pop ax
	pop bp
	ret 10
endp physics_dots

; input: 16 bit padding, number (16 bit)
; output: number squared (32 bit)
proc msquare
	push bp
	mov bp, sp
	push ax
	push cx
	push edx
	
	mov cx, [bp+4]
	mov ax, cx
	mul cx
	shl edx, 16
	mov dx, ax
	mov [bp+4], edx
	
	pop edx
	pop cx
	pop ax
	pop bp
	ret
endp msquare

; input: fpu in memory, number (32 bit)
; output: square root of number (32 bit)
proc msqrt
	push bp
	mov bp, sp
	push eax	
	push di
	
	mov eax, [bp+4]
	mov di, [bp+8]
	
	mov [di], eax
	fild [dword ptr di]
	fsqrt
	fstp [dword ptr di]
	
	mov eax, [di]
	mov [bp+6], eax
	
	pop di
	pop eax
	pop bp
	ret 2
endp msqrt

; input: fpu in memory, dx, dy
; output: distance (32 bit)
proc distance
	push bp
	mov bp, sp
	push eax
	push edx
	push di
	push si
	
	xor eax, eax
	xor edx, edx
	
	mov di, [bp+4]
	mov si, [bp+6]
	
	; mov di, di*di
	push di
	push di
	call msquare
	pop eax
	
	; mov si, si*si
	push si
	push si
	call msquare
	pop edx
	
	; mov ax, di+si
	add eax, edx
	
	; mov ax, sqrt ax
	push [word ptr bp+8]
	push eax
	call msqrt
	pop eax
	
	mov [bp+6], eax
	
	pop si
	pop di
	pop edx
	pop eax
	pop bp
	ret 2
endp distance

; input: fpu in memory, sticks start in memory, stick amount, dots start in memory, stick length start in memory
; output: none
proc sticks_length_init
	push bp
	mov bp, sp
	push eax
	push bx
	push cx
	push dx
	push di
	push si
	
	mov cx, [bp+8]
	sticks_length_init_loop:
		cmp cx, 0
		je sticks_length_init_loop_exit
		
		; get both dot's x and y location
			mov bx, [bp+10]
			push bx
			push cx
			call array_access
			pop bx
			mov di, [bx]
			mov si, [bx+2]
			
			mov bx, [bp+6]
			push bx
			push di
			call array_access
			pop di
			
			push bx
			push si
			call array_access
			pop si
		
		; calculate dx and dy
			; dx
			mov ax, [di]
			cmp ax, [si]
			jl sticks_length_init_dx
				sub ax, [si]
				jmp sticks_length_init_dx_after
			sticks_length_init_dx:
				mov ax, [si]
				sub ax, [di]
			sticks_length_init_dx_after:
			
			; dy
			mov dx, [di+2]
			cmp dx, [si+2]
			jl sticks_length_init_dy
				sub dx, [si+2]
				jmp sticks_length_init_dy_after
			sticks_length_init_dy:
				mov dx, [si+2]
				sub dx, [di+2]
			sticks_length_init_dy_after:
		
		push [word ptr bp+12]
		push ax
		push dx
		call distance
		pop eax
		
		push [word ptr bp+4]
		push cx
		call array_access
		pop bx
		mov [bx], eax
	
	dec cx
	jmp sticks_length_init_loop
	
	sticks_length_init_loop_exit:
	pop si
	pop di
	pop dx
	pop cx
	pop bx
	pop eax
	pop bp
	ret 10
endp sticks_length_init

; input: fpu in memory, wall dots start in memory, prev dots arrat start in memory, dots array start in memory, point A, point B, offset X (32 bit), offset Y (32 bit)
; output: none
proc change
	push bp
	mov bp, sp
	push eax
	push bx
	push edx
	push di
	push si
	
	; final = position
		; get first point location in memory
		push [word ptr bp+16]
		push [word ptr bp+14]
		call array_access
		pop bx
		
		mov di, [bx]
		mov si, [bx+2]
	
	; if final[0] > other[0]:
		; final[0] += offsetX
	; else:
		; final[0] -= offsetX
	; if final[1] > other[1]:
		; final[1] += offsetY
	; else:
		; final[1] -= offsetY
	
	; round offsets
		mov bx, [bp+22]
		
		mov eax, [bp+8]
		mov [bx], eax
		fld [dword ptr bx]
		frndint
		fistp [dword ptr bx]
		mov eax, [bx]
		
		mov edx, [bp+4]
		mov [bx], edx
		fld [dword ptr bx]
		frndint
		fistp [dword ptr bx]
		mov edx, [bx]
	
	; get other point location in memory
	push [word ptr bp+16]
	push [word ptr bp+12]
	call array_access
	pop bx
	
	cmp di, [bx]
	jle change_x_smaller
	add di, ax
	jmp change_x_after
	change_x_smaller:
	sub di, ax
	change_x_after:
	
	cmp si, [bx+2]
	jle change_y_smaller
	add si, dx
	jmp change_y_after
	change_y_smaller:
	sub si, dx
	change_y_after:
	
	
	; wall
		push [word ptr bp+16]
		push [word ptr bp+14]
		call array_access
		pop bx
		
		push [word ptr bp+20]
		push [word ptr bp+14]
		push di
		push si
		push [word ptr bx]
		push [word ptr bx+2]
		
		push [word ptr bp+18]
		push [word ptr bp+14]
		call array_access
		call wall
		pop si
		pop di
		pop dx
		pop ax
		
	; return final
		mov [bx], di
		mov [bx+2], si
		
		push [word ptr bp+16]
		push [word ptr bp+14]
		call array_access
		pop bx
		
		mov [bx], ax
		mov [bx+2], dx
	
	pop si
	pop di
	pop edx
	pop bx
	pop eax
	pop bp
	ret 20
endp change

; input: locked color, wall dots start in memory, prev dots start in memory, fpu in memory, dots start in memory, stick lengths start in memory, sticks start in memory, sticks amount
; output: none
proc physics_sticks
	push bp
	mov bp, sp
	push eax
	push bx
	push ecx
	push edx
	push di
	push si
	
	mov cx, [bp+4]
	physics_sticks_loop:
		cmp cx, 0
		jne physics_sticks_loop_continue
		jmp physics_sticks_end
		physics_sticks_loop_continue:
		
		push cx
		
		; get both dot's x and y location
			mov bx, [bp+6]
			push bx
			push cx
			call array_access
			pop bx
			mov di, [bx]
			mov si, [bx+2]
			
			mov bx, [bp+10]
			push bx
			push di
			call array_access
			pop di
			
			push bx
			push si
			call array_access
			pop si
		
		; calculate dx and dy
			; dx
			mov ax, [di]
			cmp ax, [si]
			jl physics_sticks_dx
				sub ax, [si]
				jmp physics_sticks_dx_after
			physics_sticks_dx:
				mov ax, [si]
				sub ax, [di]
			physics_sticks_dx_after:
			
			; dy
			mov dx, [di+2]
			cmp dx, [si+2]
			jl physics_sticks_dy
				sub dx, [si+2]
				jmp physics_sticks_dy_after
			physics_sticks_dy:
				mov dx, [si+2]
				sub dx, [di+2]
			physics_sticks_dy_after:
			
			mov di, ax
			mov si, dx
			
		; set bx to fpu in memory
		mov bx, [bp+12]
		
		push bx
		push ax
		push dx
		call distance
		pop eax
		
		; get original stick length
		push [word ptr bp+8]
		push cx
		call array_access
		pop bx
		mov edx, [bx]
		
		; set bx to fpu in memory
		mov bx, [bp+12]
		
		; difference = stick.length - distance
		mov [bx], edx
		fld [dword ptr bx]
		mov [bx], eax
		fld [dword ptr bx]
		fsub
		fstp [dword ptr bx]
		mov edx, [bx]
		cmp edx, 0
		je physics_sticks_dont_change
		
		; percent = difference / distance / 2
		mov [bx], edx
		fld [dword ptr bx]
		mov [bx], eax
		fld [dword ptr bx]
		fdiv
		mov [dword ptr bx], 2
		fild [dword ptr bx]
		fdiv
		fstp [dword ptr bx]
		mov edx, [bx]
		
		push cx
		; offsetX = dx * percent
		xor eax, eax
		mov ax, di
		mov [bx], eax
		fild [dword ptr bx]
		mov [bx], edx
		fld [dword ptr bx]
		fmul
		fstp [dword ptr bx]
		mov ecx, [bx]
		
		; offsetY = dy * percent
		xor eax, eax
		mov ax, si
		mov [bx], eax
		fild [dword ptr bx]
		mov [bx], edx
		fld [dword ptr bx]
		fmul
		fstp [dword ptr bx]
		mov edx, [bx]
		
		mov eax, ecx
		pop cx
		
		; -------------------------------
		; implements locking dots:
			; if not stick.pointA.locked:
				; if stick.pointB.locked:
					; offsetX *= 2
					; offsetY *= 2
				; stick.pointA.position = Change(stick.pointA.position, stick.pointB.position, offsetX, offsetY)
			; else:
				; offsetX *= 2
				; offsetY *= 2
			; if not stick.pointB.locked:
				; stick.pointB.position = Change(stick.pointB.position, stick.pointA.position, offsetX, offsetY)
		; -------------------------------
		
		locking:
		push ax
		push bx
			; get dots in memory
				mov bx, [bp+6]
				push bx
				push cx
				call array_access
				pop bx
				mov di, [bx]
				mov si, [bx+2]
				
				mov bx, [bp+10]
				push bx
				push di
				call array_access
				pop di
				
				push bx
				push si
				call array_access
				pop si
			
			mov ax, [di+4]
			cmp ax, [bp+18]
			je a_locked
			
				mov ax, [si+4]
				cmp ax, [bp+18]
				jne b_not_locked
					mov bx, [bp+12]
					
					mov [bx], eax
					fld [dword ptr bx]
					fld [dword ptr bx]
					fadd 
					fstp [dword ptr bx]
					mov eax, [bx]
					
					mov [bx], edx
					fld [dword ptr bx]
					fld [dword ptr bx]
					fadd 
					fstp [dword ptr bx]
					mov edx, [bx]
				
				b_not_locked:
					; stick.pointA.position = Change(stick.pointA.position, stick.pointB.position, offsetX, offsetY)
					push [word ptr bp+12]
					push [word ptr bp+16]
					push [word ptr bp+14]
					push [word ptr bp+10]
						mov bx, [bp+6]
						push bx
						push cx
						call array_access
						pop bx
					push [word ptr bx]
					push [word ptr bx+2]
					push eax
					push edx
					call change
					
					jmp b_check
			
			a_locked:
				mov bx, [bp+12]
				
				mov [bx], eax
				fld [dword ptr bx]
				fld [dword ptr bx]
				fadd 
				fstp [dword ptr bx]
				mov eax, [bx]
				
				mov [bx], edx
				fld [dword ptr bx]
				fld [dword ptr bx]
				fadd 
				fstp [dword ptr bx]
				mov edx, [bx]
			
			b_check:
				mov ax, [si+4]
				cmp ax, [bp+18]
				je b_locked
					
					; stick.pointB.position = Change(stick.pointB.position, stick.pointA.position, offsetX, offsetY)
					push [word ptr bp+12]
					push [word ptr bp+16]
					push [word ptr bp+14]
					push [word ptr bp+10]
						mov bx, [bp+6]
						push bx
						push cx
						call array_access
						pop bx
					push [word ptr bx+2]
					push [word ptr bx]
					push eax
					push edx
					call change
			b_locked:
		pop bx
		pop ax
		
		physics_sticks_dont_change:
		pop cx
	
	dec cx
	je physics_sticks_end
	jmp physics_sticks_loop
	
	physics_sticks_end:
	pop si
	pop di
	pop edx
	pop ecx
	pop bx
	pop eax
	pop bp
	ret 16
endp physics_sticks

; input: locked color, stick lengths start in memory, fpu in memory, dots wall start in memory, dots start in memory, previous dots start in memory, dots amount, sticks start in memory, sticks amount
; output: none
proc physics
	push bp
	mov bp, sp
	push cx
	
	push [word ptr bp+20]
	push [word ptr bp+14]
	push [word ptr bp+12]
	push [word ptr bp+10]
	push [word ptr bp+8]
	call physics_dots
	
	mov cx, 5
		physics_loop_sticks:
		push [word ptr bp+20]
		push [word ptr bp+14]
		push [word ptr bp+10]
		push [word ptr bp+16]
		push [word ptr bp+12]
		push [word ptr bp+18]
		push [word ptr bp+6]
		push [word ptr bp+4]
		call physics_sticks
	loop physics_loop_sticks
	
	pop cx
	pop bp
	ret 20
endp physics

; input: button's position in memory, previous button's position in memory, new button
; output: valid click - 1; non-valid click / no click - 0
proc click
	push bp
	mov bp, sp
	push ax
	push bx
	push cx
	push dx
	
	mov bx, [bp+8]
	mov cx, [bx]
	mov bx, [bp+6]
	mov dx, [bx]
	mov [bx], cx
	
	mov bx, [bp+8]
	mov ax, [bp+4]
	mov [bx], ax
	
	mov ax, 0
	
	cmp cx, dx
	je click_end
	mov ax, [bp+4]
	
	click_end:
	mov [bp+8], ax
	pop dx
	pop cx
	pop bx
	pop ax
	pop bp
	ret 4
endp click

; input: dot amount, dots start in memory, prev dots start in memory
; output: none
proc copy_dots
	push bp
	mov bp, sp
	push bx
	push cx
	push di
	
	mov cx, [bp+8]
	dots_prev_copy:
		push [word ptr bp+6]
		push cx
		call array_access
		pop di
		
		push [word ptr bp+4]
		push cx
		call array_access
		pop bx
		
		push cx
		mov cx, 3
		dots_prev_copy_loop:
			mov ax, [di]
			mov [bx], ax
			add di, 2
			add bx, 2
		loop dots_prev_copy_loop
		pop cx
	loop dots_prev_copy
	
	pop di
	pop cx
	pop bx
	pop bp
	ret 6
endp copy_dots

; input: saved color in memory, dots in memory, selected color in memory, new select, select in memory
; output: none
proc select
	push bp
	mov bp, sp
	push ax
	push bx
	push di
	
	mov bx, [bp+4]
	mov di, [bp+6]
	mov [bx], di
	
	push [word ptr bp+10]
	push di
	call array_access
	pop di
	
	; save color
	mov bx, [bp+12]
	mov ax, [di+4]
	mov [bx], ax
	
	mov bx, [bp+8]
	mov [di+4], bx
	
	
	pop di
	pop bx
	pop ax
	pop bp
	ret 10
endp select

; input: dots in memory, saved color, select in memory
; output: none
proc deselect
	push bp
	mov bp, sp
	push bx
	push di
	
	push [word ptr bp+8]
	mov bx, [bp+4]
	push [bx]
	call array_access
	pop di
	
	mov bx, [bp+6]
	mov [di+4], bx
	
	mov bx, [bp+4]
	mov [word ptr bx], 0
	
	pop di
	pop bx
	pop bp
	ret 6
endp deselect
	
start:
	mov ax, @data
	mov ds, ax
	
	; setup graphic mode
		mov ax, 0A000h
		mov es, ax
		mov ax, 13h
		int 10h
		call clear
	
	; setup mouse
		mov ax, 0
		int 33h
		mov ax, 1
		int 33h
	
	; initial render
		mov bx, offset dots_wall_prev
		push bx
		mov bx, offset dots_prev
		push bx
		mov bx, offset dots
		push bx
		mov bx, [dot_amount]
		push bx
		mov bx, [dot_size]
		push bx
		mov bx, offset sticks
		push bx
		mov bx, [stick_amount]
		push bx
		call render
	
	; sandbox loop
	sandbox:
		; get mouse input
		mov ax, 3
		int 33h
		mov ax, bx
		
		; process mouse input
		mov ah, al
		and ah, 1b
		and al, 10b
		sar cx, 1
		
		; check left mouse button
		sandbox_left:
			mov bx, offset left
			push bx
			mov bx, offset left_prev
			push bx
			xor bx, bx
			mov bl, ah
			push bx
			call click
			pop bx
			cmp bx, 1
			jne sandbox_right
		
			; hide mouse
			mov ax, 2
			int 33h
			
			; add dot to dots array
			push cx
			push dx
			push [dot_color]
			mov bx, offset dots
			push bx
			mov bx, offset dot_amount
			push bx
			call array_add
		
		; check right mouse button
		sandbox_right:
			mov bx, offset right
			push bx
			mov bx, offset right_prev
			push bx
			xor bx, bx
			sar al, 1
			mov bl, al
			push bx
			call click
			pop bx
			cmp bx, 1
			jne keyboard
			
			; check if a dot is pressed
			mov bx, offset dots
			push bx
			push cx
			push dx
			call search_dots_by_position
			pop di
			
			; handle search results
			cmp di, 0
			je keyboard
			
			cmp [word ptr selected], 0
			je add_select
			cmp [word ptr stick_handle], 1
			je add_stick
			cmp [selected], di
			je only_deselect
			
			switch_select:
				mov bx, offset dots
				push bx
				mov bx, offset saved_color
				push [word ptr bx]
				mov bx, offset selected
				push bx
				call deselect
				
				mov bx, offset saved_color
				push bx
				mov bx, offset dots
				push bx
				mov bx, offset selected_color
				push [word ptr bx]
				push di
				mov bx, offset selected
				push bx
				call select
			jmp keyboard
			
			only_deselect:
				mov bx, offset dots
				push bx
				mov bx, offset saved_color
				push [word ptr bx]
				mov bx, offset selected
				push bx
				call deselect
			jmp keyboard
			
			add_select:
				mov bx, offset saved_color
				push bx
				mov bx, offset dots
				push bx
				mov bx, offset selected_color
				push [word ptr bx]
				push di
				mov bx, offset selected
				push bx
				call select
			jmp keyboard
			
			add_stick:
				mov [word ptr stick_handle], 0
				
				push [word ptr selected]
				push di
				push [word ptr stick_color]
				mov bx, offset sticks
				push bx
				mov bx, offset stick_amount
				push bx
				call array_add
				
				; deselect
				mov bx, offset dots
				push bx
				mov bx, offset saved_color
				push [word ptr bx]
				mov bx, offset selected
				push bx
				call deselect
			jmp keyboard
		
		; check keyboard input
		keyboard:
			; check if a key is pressed
				mov ax, 100h
				int 16h
				jz sandbox_end
				
				; if a key is pressed, get pressed key
				mov ax, 0
				int 16h
				
				cmp al, 13
				je keyboard_enter
				cmp al, ' '
				je keyboard_space
				cmp al, 8
				je keyboard_backspace
				jmp sandbox_end
				
				keyboard_enter:
					mov [mode], 1
					jmp sandbox_end
				
				keyboard_space:
					cmp [word ptr selected], 0
					je sandbox_end
					xor [word ptr stick_handle], 1
					jmp sandbox_end
				
				keyboard_backspace:
					cmp [word ptr selected], 0
					je sandbox_end
					
					mov di, [word ptr selected]
					mov bx, offset dots
					push bx
					push di
					call array_access
					pop di
					
					mov dx, [locked_color]
					cmp [di+4], dx
					je keyboard_backspace_deselect
						mov [di+4], dx
						mov [word ptr selected], 0
						jmp sandbox_end
					keyboard_backspace_deselect:
						mov dx, [dot_color]
						mov [di+4], dx
						mov [word ptr selected], 0
						jmp sandbox_end
		
		sandbox_end:
		
		; clear and render
		call clear
		mov bx, offset dots_wall_prev
		push bx
		mov bx, offset dots_prev
		push bx
		mov bx, offset dots
		push bx
		mov bx, [dot_amount]
		push bx
		mov bx, [dot_size]
		push bx
		mov bx, offset sticks
		push bx
		mov bx, [stick_amount]
		push bx
		call render
		
		; reshow mouse
		mov ax, 1
		int 33h
		
		; check mode
		mov bx, offset mode
		mov ax, 1
		cmp [bx], ax
		je sandbox_after
		jmp sandbox
	sandbox_after:
	
	; hide mouse
	mov ax, 2
	int 33h
	
	; deselect
	mov bx, offset dots
	push bx
	mov bx, offset saved_color
	push [word ptr bx]
	mov bx, offset selected
	push bx
	call deselect
	
	; copy dots to prev dots
	mov bx, [dot_amount]
	push bx
	mov bx, offset dots
	push bx
	mov bx, offset dots_prev
	push bx
	call copy_dots
	
	; calculate stick lengths
	mov bx, offset fpu
	push bx
	mov bx, offset sticks
	push bx
	mov bx, [stick_amount]
	push bx
	mov bx, offset dots
	push bx
	mov bx, offset sticks_length
	push bx
	call sticks_length_init
	
	; simulation loop
	simulation:
		; simulation
		mov bx, offset locked_color
		push [word ptr bx]
		mov bx, offset sticks_length
		push bx
		mov bx, offset fpu
		push bx
		mov bx, offset dots_wall_prev
		push bx
		mov bx, offset dots
		push bx
		mov bx, offset dots_prev
		push bx
		mov bx, [dot_amount]
		push bx
		mov bx, offset sticks
		push bx
		mov bx, [stick_amount]
		push bx
		call physics
		
		; clear screen
		mov cx, 1
		cmp [nuclear], cx
		je skip_clear
		call clear
		skip_clear:
		
		; render
		mov bx, offset dots_wall_prev
		push bx
		mov bx, offset dots_prev
		push bx
		mov bx, offset dots
		push bx
		mov bx, [dot_amount]
		push bx
		mov bx, [dot_size]
		push bx
		mov bx, offset sticks
		push bx
		mov bx, [stick_amount]
		push bx
		call render
		
		call delay_physics
		
		; check if key pressed
		mov ax, 100h
		int 16h
		jz simulation
		
		; if a key is pressed, get pressed key
		mov ax, 0
		int 16h
		
		cmp al, 13
		jne simulation
	
	end_program:
	; exit graphic mode
	mov ax, 2
	int 10h
	
exit:
	mov ax, 4c00h
	int 21h
END start

; TODO

; SCREENS
; make starting screen
; make instructions
; make control panel

; OPTIONAL
; add double buffering
; add decimal point values
; add templates
; increase screen size
; sans. (?)
