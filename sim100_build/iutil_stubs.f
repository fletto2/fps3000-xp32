C       Working stubs for IUTIL routines that SIM100 calls.
C       AREAD/IREAD actually read from stdin so the simulator can
C       interact with the user.
C
        SUBROUTINE TERM
        RETURN
        END
        SUBROUTINE SETTY (M)
        INTEGER M
        RETURN
        END
        SUBROUTINE GTFIL (ISL, ITTI, ITTO)
        INTEGER ISL, ITTI, ITTO
        ITTI = 5
        ITTO = 6
        RETURN
        END
        SUBROUTINE CLFIL (LUN)
        INTEGER LUN
        RETURN
        END
C
C       AREAD = read an alphabetic token from LUN.
C       Returns the character class as the function value (-1=EOF,
C       -2=numeric, 0=alpha, etc.). For our purposes we just read
C       a line and return the first non-blank char.
        INTEGER FUNCTION AREAD (LUN, BUF, MAX, ICHK, ICHR, IPTR)
        INTEGER LUN, BUF(*), MAX, ICHK, ICHR, IPTR
        CHARACTER LINE*256
        INTEGER I, NCH
        READ (5, '(A)', END=900) LINE
        NCH = 0
        DO 10 I = 1, MIN(MAX, 256)
          IF (LINE(I:I) .NE. ' ') THEN
            NCH = NCH + 1
            BUF(NCH) = ICHAR(LINE(I:I))
            IF (NCH .GE. MAX) GOTO 20
          ELSE IF (NCH .GT. 0) THEN
            GOTO 20
          ENDIF
10      CONTINUE
20      CONTINUE
        IPTR = 1
        IF (NCH .GT. 0) THEN
          ICHR = BUF(1)
        ELSE
          ICHR = 0
        ENDIF
        AREAD = NCH
        RETURN
900     AREAD = -1
        ICHR = 0
        IPTR = 1
        RETURN
        END
C
C       IREAD = read an integer (decimal/octal) from LUN.
        INTEGER FUNCTION IREAD (LUN, IVAL, ICHK, ICHR, IPTR, IRADIX)
        INTEGER LUN, IVAL, ICHK, ICHR, IPTR, IRADIX
        CHARACTER LINE*256
        READ (5, '(A)', END=900) LINE
        READ (LINE, *, ERR=900) IVAL
        IREAD = 1
        ICHR = 0
        IPTR = 1
        RETURN
900     IREAD = -1
        IVAL = 0
        ICHR = 0
        IPTR = 1
        RETURN
        END
C
        INTEGER FUNCTION FREAD (LUN, FVAL, ICHK, ICHR, IPTR)
        INTEGER LUN, ICHK, ICHR, IPTR
        REAL FVAL
        CHARACTER LINE*256
        READ (5, '(A)', END=900) LINE
        READ (LINE, *, ERR=900) FVAL
        FREAD = 1
        ICHR = 0
        IPTR = 1
        RETURN
900     FREAD = -1
        FVAL = 0.0
        ICHR = 0
        IPTR = 1
        RETURN
        END
C
        SUBROUTINE NUMOUT (NUM, DIGIT, NDIG, IRADIX)
        INTEGER NUM, DIGIT(*), NDIG, IRADIX
        CHARACTER FMT*12, LINE*32
        INTEGER N, I
        IF (IRADIX .EQ. 8) THEN
          WRITE (LINE, '(O11)') NUM
        ELSE IF (IRADIX .EQ. 16) THEN
          WRITE (LINE, '(Z8)') NUM
        ELSE
          WRITE (LINE, '(I11)') NUM
        ENDIF
        N = LEN_TRIM(LINE)
        DO 10 I = 1, MIN(N, 32)
          DIGIT(I) = ICHAR(LINE(I:I))
10      CONTINUE
        NDIG = N
        RETURN
        END
C
        INTEGER FUNCTION IAND16 (A, B)
        INTEGER A, B
        IAND16 = IAND(A, B)
        RETURN
        END
C
        INTEGER FUNCTION IRSH16 (A, N)
        INTEGER A, N
        IRSH16 = ISHFT(A, -N)
        IF (IRSH16 .LT. 0) IRSH16 = IRSH16 + 65536
        RETURN
        END
