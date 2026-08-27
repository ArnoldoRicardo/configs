" ~/.vimrc — Arturo. El mismo archivo en think-x1 y en cyxpc-b.
" Sin gestor de plugins ni dependencias: esto es vim pelón, arranca igual
" de rápido por ssh que en local.

set nocompatible
syntax on
filetype plugin indent on
let mapleader = ','          " el mismo leader que traías en el init.vim de nvim

" ---------- básico ----------
set number
set hidden
set backspace=indent,eol,start
set encoding=utf-8
set ttimeoutlen=10           " que <Esc> no se sienta lento por ssh
set lazyredraw               " menos repintado en conexión remota
set scrolloff=3
set laststatus=2
set ruler
set showcmd
set wildmenu
set wildmode=longest:full,full
set nowrap
set mouse=                   " ratón OFF a propósito: el arrastre sigue siendo
                             " selección de Terminator, no visual mode de vim

" ---------- búsqueda ----------
set incsearch
set hlsearch
set ignorecase
set smartcase
nnoremap <silent> <leader><space> :nohlsearch<CR>

" ---------- indentación ----------
set expandtab shiftwidth=2 softtabstop=2 tabstop=2
set autoindent smartindent
autocmd FileType python,sh setlocal shiftwidth=4 softtabstop=4
autocmd FileType make setlocal noexpandtab

" ---------- archivos ----------
set noswapfile
set nobackup
set nowritebackup
silent! call mkdir(expand('~/.vim/undo'), 'p', 0700)
set undofile
set undodir=~/.vim/undo
" volver a donde dejaste el cursor
autocmd BufReadPost * if line("'\"") > 0 && line("'\"") <= line("$") | exe "normal! g`\"" | endif

" ---------- colores ----------
set background=dark
silent! colorscheme habamax

" ---------- ventanas y buffers ----------
noremap <leader>h :<C-u>split<CR>
noremap <leader>v :<C-u>vsplit<CR>
noremap <leader>q :bp<CR>
noremap <leader>w :bn<CR>
noremap <leader>c :bd<CR>

" =====================================================================
" PORTAPAPELES
" Dos caminos, mismas teclas en las dos máquinas:
"   think-x1 con vim-gtk3 y sesión X -> CLIPBOARD directo por X11.
"   cyxpc-b (o cualquier ssh)        -> OSC 52, que sshclip traduce al
"                                       portapapeles de la laptop.
"   ,y  copiar la selección visual      ,Y  copiar la línea actual
"   :Copy  copiar todo el archivo (o un rango: :'<,'>Copy, :10,20Copy)
" Pegar DESDE la laptop hacia vim remoto: Ctrl+Shift+V (bracketed paste,
" no hace falta :set paste).
" =====================================================================
if has('clipboard') && !empty($DISPLAY)
  " y copia al portapapeles del sistema. d, x y c NO lo tocan: siguen yendo
  " al registro de vim, asi que borrar una letra no te borra lo que copiaste
  " en el navegador. Y "dd + p" para mover una linea sigue funcionando igual.
  nnoremap y "+y
  nnoremap Y "+yy
  xnoremap y "+y
  " pegar lo que copiaste FUERA de vim: ,p  (o Ctrl+Shift+V en insert)
  nnoremap <leader>p "+p
  xnoremap <leader>y "+y
  nnoremap <leader>Y "+yy
  command! -range=% Copy silent execute <line1> . ',' . <line2> . 'yank +'

  " En X11 el portapapeles muere con el proceso que lo posee, y clipman no
  " captura lo de vim. Al salir le pasamos el contenido a xsel, que se queda
  " de fondo sirviendolo.
  function! s:KeepClipboard() abort
    let l:t = getreg('+')
    if !empty(l:t) && executable('xsel')
      call system('xsel -ib', l:t)
    endif
  endfunction
  augroup vimrc_clipboard
    autocmd!
    autocmd VimLeave * call s:KeepClipboard()
  augroup END
else
  function! s:Osc52(text) abort
    let l:b64 = system('base64 | tr -d "\n"', a:text)
    if v:shell_error
      echohl ErrorMsg | echo 'OSC52: falló base64' | echohl None
      return
    endif
    silent! call writefile(["\<Esc>]52;c;" . l:b64 . "\<Char-0x07>"], '/dev/tty', 'b')
    echo 'copiado al portapapeles (' . len(a:text) . ' bytes)'
  endfunction

  xnoremap <silent> <leader>y y:call <SID>Osc52(@")<CR>
  nnoremap <silent> <leader>Y :call <SID>Osc52(getline('.') . "\n")<CR>
  command! -range=% Copy call <SID>Osc52(join(getline(<line1>, <line2>), "\n") . "\n")
endif
