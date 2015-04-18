
.PHONY: default
default:
	@echo "@@@@@@@@@@@@@@@@@@@@@"
	@echo "       You can do :"
	@echo " make all"
	@echo " make clean"
	@echo " make html"
	@echo " make htm"
	@echo " make txt"
	@echo " make ps"
	@echo " make info"
	@echo " make lyx"
	@echo " make dvi"
	@echo " make tex"
	@echo " make rtf"
	@echo "@@@@@@@@@@@@@@@@@@@@@"

.PHONY: all html htm txt rtf dvi info lyx ps tex
all: html htm  txt rtf dvi ps lyx tex

clean: 
	cd html;\
	make clean
	cd htm;\
	make clean
	cd txt;\
	make clean
	cd rtf;\
	make clean
	cd dvi;\
	make clean
	cd info;\
	make clean
	cd lyx;\
	make clean
	cd ps;\
	make clean
	cd tex;\
	make clean
	find . -name "*~" -exec rm  {} \;

html:
	cd html;\
	make

htm: 
	cd htm;\
	make

txt: 
	cd txt;\
	make

rtf:
	cd rtf;\
	make

dvi:
	cd dvi;\
	make

info:
	cd info;\
	make

lyx:
	cd lyx;\
	make

ps:
	cd ps;\
	make

tex:
	cd tex;\
	make

