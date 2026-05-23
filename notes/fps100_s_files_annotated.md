# FPS-100 AP-side supervisor (.S files) — annotated reference

36 APAL source files (7055 lines) implementing the AP-side supervisor that runs on the FPS-100 in Super-100 / Mini-100 modes. Council-of-Clankers analysis (DS + GLM, cooperative + adversarial).


---

## Group: `kernel_core`

**Core Mini-100/Super-100 kernel**

Files: `KERNEL.S`

### DeepSeek final

(adv 119s, 26910c)

## Critique of Peer Analysis

The peer analysis provides a reasonable high-level overview but has several significant shortcomings:

1. **Missing architectural details**: Fails to explain the critical `SYSPTR`/`SYSAVE` mechanism that distinguishes ISR returns from task returns in `INTEXT`
2. **Incorrect timing analysis**: States "48 cycles for same-task resumption" but the source code explicitly documents 48 cycles *including* called routines
3. **Oversimplifies context management**: Doesn't explain the `LSTFUL` (last full-context task) optimization that avoids redundant saves
4. **Ignores AP-specific idioms**: Misses the `LDSPE`/`ADD R6` pattern for adjusting sign-extended loads, the `WRTLMN` instruction for marking overlay residency, and the `MOV R0,R0; SETMA` no-op pattern for pipeline synchronization
5. **Incomplete register analysis**: Doesn't document which S-Pad registers are actually used as scratch vs. parameter passing
6. **Missing cross-references**: Doesn't connect `COMSYS`/`SYSDEF` includes to the system data structures they define

---

# KERNEL.S — Core Mini-100/Super-100 Kernel Analysis

## 1. Subsystem Overview

`KERNEL.S` implements the **AP-side supervisor kernel** for the FPS-100 when operating in Super-100 or Mini-100 mode (as opposed to AP-120B mode where the host fully controls the array processor). This is the code that runs **on the AP-120B itself**, managing:

- **Task scheduling**: Priority-based selection from a ready queue, with minimal/full context switching
- **Program Store (PS) overlay management**: Loading code segments from Main Data (MD) memory into PS via a 2:1 word compression
- **Interrupt dispatch**: I/O interrupts, Real-Time Clock (RTC), traps (SVC calls), and fatal exceptions
- **Queue management**: Doubly-linked circular queues for ready tasks, clock timeouts, and terminated tasks
- **Context save/restore**: Two-tier system (minimal vs. full context) optimized to avoid redundant saves

The kernel operates exclusively in **supervisor mode** with **SMA** (Supervisor Memory Address) and **interrupts off** during critical sections, switching to user mode only during code transfers (`MOVER`) and ISR execution.

## 2. Per-File Purpose

### KERNEL.S (1216 lines total) — Contains 14 separate modules

---

### Module: EXTASK — "EXECUTE TASK MODULE" (lines 1-97)

**$TITLE**: `EXTASK`  
**$ENTRY**: `EXTASK,0`  
**$EXT**: `EMPTY`, `CHKPT`, `IDLE`, `MXSAVE`, `MNREST`, `MXREST`, `PSMNGR`  
**$INSERT**: `COMSYS`

**Purpose**: Main task scheduler. Selects the highest-priority ready task, ensures its overlay segments are resident in PS, performs context switch if needed, and loads the new task's minimal state.

**AP State Manipulated**:
- **S-Pad**: SP0 (output = end of min save area), SP1, SP5-7 (scratch)
- **DPX**: DPX2 (input = ready queue header), DPX3 (TCB address from EMPTY)
- **MD**: `CURTSK`, `NEWTSK`, `LSTFUL`, `STATUS`, `OVLPTR`, `MINTCB`, `MAXTCB`, `CXTBIT`
- **APSTAT**: Interrupts remain off throughout

**Key Constants**:
- `STAT = 0`, `FULLC = 1`, `HERE = 0`, `LAST = 5`, `NEW = 6`, `CUR = 7` (S-Pad register assignments)

**Cross-references**: Called by `INTEXT`; calls `EMPTY`, `CHKPT`, `IDLE`, `MXSAVE`, `MXREST`, `MNREST`, `PSMNGR`

---

### Module: PSMNGR — "PS MANAGER" (lines 98-233)

**$TITLE**: `PSMNGR`  
**$ENTRY**: `PSMNGR,0`  
**$EXT**: `MOVER`  
**$INSERT**: `COMSYS`

**Purpose**: Manages PS (Program Store) memory residency. For each overlay segment that should be resident, checks if it currently is. If not, finds its PS partition(s), marks the previous occupant(s) as non-resident, marks the new segment resident, and calls `MOVER` to transfer code from MD to PS. Re-checks all segments after transfer (in case of interruption).

**AP State Manipulated**:
- **S-Pad**: SP0-6 (scratch), SP7 explicitly NOT used
- **DPX**: DPX0-3 (scratch), DPX2-3 (parameters)
- **MD**: Overlay table entries (8 words each), `SYSPTR`
- **PS**: Modified indirectly via `MOVER`

**Overlay Table Format** (8 words per entry):
```
Word 1: Overlay segment number
Word 2: MD address
Word 3: PS address
Word 4: Length (in PS words)
Word 5: Task ID or TCB address
Word 6: Residency word (EXP=currently res, LM=should be res)
Word 7: Pointer to first PS partition table entry
Word 8: Number of PS partition entries
```

**Key Technique**: Uses `WRTLMN` instruction to atomically mark old segments as "should be resident but isn't" — this is a write-to-LM (Local Memory) operation that modifies the residency word in the overlay table.

**Cross-references**: Called by `EXTASK` and `IO`; calls `MOVER`

---

### Module: MOVER — "CODE MOVER" (lines 234-296)

**$TITLE**: `MOVER`  
**$ENTRY**: `MOVER,0`  
**$EXT**: (none)

**Purpose**: Transfers code from MD to PS at 2:1 compression (2 MD words = 1 PS word). Switches to user mode with interrupts enabled during the transfer, then returns to supervisor mode.

**AP State Manipulated**:
- **S-Pad**: SP0 (scratch, used as counter)
- **DPX**: DPX0 (PS address), DPX1 (MD address), DPX2 (word count), DPX3 explicitly NOT used
- **TMA**: Used as PS address pointer
- **APSTAT**: `CLRMOD` (user mode), `ION` (interrupts on), `ENTINT` (supervisor mode, interrupts on, SMA)
- **MA**: Switched between supervisor and user via `SELMA`

**Critical Timing Note**: The loop is a carefully crafted 3-instruction, 5-cycle loop that exploits the AP-120B's dual-column instruction execution. The comment explicitly documents the pipeline assumption: "in the instructions which increment MA and load PS, both of these will happen in the same cycle of the 2 cycles it takes to execute."

**Cross-references**: Called by `PSMNGR`

---

### Module: IO — "I/O INTERRUPT HANDLER" (lines 297-408)

**$TITLE**: `IO`  
**$ENTRY**: `IO,0`  
**$EXT**: `RMVCLK`, `PSMNGR`, `RTCINT`, `INTEXT`  
**$INSERT**: `COMSYS`  
**$COMMON**: `/CONFIG/` — 15 device configuration entries (DEV1-DEV15), each 5 words

**Purpose**: Handles I/O interrupts. Masks further interrupts from the interrupting device and lower-priority devices, ensures the ISR is resident in PS, JSR's to it, then re-adjusts the IMASK register on return.

**AP State Manipulated**:
- **S-Pad**: SP0-4, SP7 (scratch; SP7 = current TCB address on entry)
- **DPX**: DPX0-3 (scratch, parameters for PSMNGR and ISR)
- **DA**: IMASK register (I/O interrupt mask)
- **MD**: Device configuration table, `SYSPTR`, `LOGIOD` (spurious interrupt counter)
- **APSTAT**: `IOINTA` (I/O interrupt acknowledge), `CLRMOD` (user mode for ISR), `ENTINT` (supervisor mode on return)

**Device Configuration Table Format** (5 words per entry):
```
Word 1: Priority mask (to mask lower-priority devices)
Word 2: Bit mask (this device's interrupt bit)
Word 3: Pointer to ISR's overlay table entry
Word 4: Device order number (EXP) / Physical device address (LM)
Word 5: Save area for old IMASK
```

**RTC Handling**: Device number 5 (RTC) is handled specially — calls `RTCINT` then `RMVCLK` before exiting via `INTEXT`.

**Spurious Interrupt Detection**: If `IOINTA` returns no device number, increments `LOGIOD` counter and exits.

**Cross-references**: Called by `CHKPT`; calls `RTCINT`, `RMVCLK`, `PSMNGR`, `INTEXT`

---

### Module: INTEXT — "INTERRUPT EXIT ROUTINE" (lines 409-442)

**$TITLE**: `INTEXT`  
**$ENTRY**: `INTEXT,0`  
**$EXT**: `EXTASK`, `MNREST`  
**$INSERT**: `COMSYS`

**Purpose**: Common interrupt exit. Determines whether the interrupted context was a user task, an ISR, or the PS manager. If a user task, goes to `EXTASK` to pick the highest-priority ready task. Otherwise, restores the interrupted state via `MNREST`.

**AP State Manipulated**:
- **S-Pad**: SP0 (output = SYSPTR-1 for MNREST), SP1 (scratch)
- **MD**: `SYSPTR`, `SYSAVE`

**Key Decision Logic**: Compares `SYSPTR` with `SYSAVE`. If equal, the interrupted context was a user task (system save area was empty). If different, an ISR or PSMNGR was interrupted.

**Cross-references**: Called by `IO`, `TRAP`, `FATAL`/`FPE`; calls `EXTASK`, `MNREST`

---

### Module: RTCINT — "RTC INTERRUPT HANDLER" (lines 443-518)

**$TITLE**: `RTCINT`  
**$ENTRY**: `RTCINT,0`  
**$EXT**: `EMPTY`, `DELETE`, `RESUME`  
**$INSERT**: `COMSYS`

**Purpose**: Handles Real-Time Clock interrupts. Gets the first element from the clock queue (a TCB address), deletes the task from the exchange where it was waiting, sends a timeout message, and puts it back into the ready queue.

**AP State Manipulated**:
- **S-Pad**: SP0-4 (scratch), SPFN (output = 0 if queue empty, TCB addr otherwise)
- **DPX**: DPX0-3 (scratch), DPX1 (output = TCB address)
- **MD**: Clock queue (`CLKQUE`), TCB fields (`RCLOCK`, `DPX0`, `SPFUNC`, `TYPE`)

**Exchange Type Management**: When deleting a task from an exchange, checks if the exchange becomes empty (by comparing RLINK and LLINK of the TCB). If so, sets the exchange type to EMPTY.

**Timeout Message**: Stores `TIMOUT` message address in TCB's DPX0, and `TIMBIT` message type in TCB's SPFN and SP0.

**Cross-references**: Called by `IO`; calls `EMPTY`, `DELETE`, `RESUME`

---

### Module: CHKPT — "CHECKPOINT" (lines 519-548)

**$TITLE**: `CHKPT`  
**$ENTRY**: `CHKPT,0`  
**$EXT**: `IO`  
**$INSERT**: `COMSYS`

**Purpose**: Checks for pending interrupts. If any device is trying to interrupt, clears the SRA (Service Request Acknowledge) bits in APSTAT3 and dispatches to `IO`.

**AP State Manipulated**:
- **S-Pad**: SP0-2, SP7 (scratch; SP7 = CURTSK for IO)
- **DA**: APST3 (APSTAT3 register)
- **MD**: `CURTSK`, `INBS`

**Key Detail**: Uses mask `176077` (octal) to clear SRA bits in APSTAT3 while preserving other status bits.

**Cross-references**: Called by `EXTASK`; calls `IO`

---

### Module: IDLE — "IDLING ROUTINE" (lines 549-572)

**$TITLE**: `IDLE`  
**$ENTRY**: `IDLE,0`  
**$EXT**: (none)

**Purpose**: Called when no tasks are ready and no I/O interrupts are pending. Maintains an idle counter in PS (not MD). User-replaceable.

**AP State Manipulated**:
- **S-Pad**: SP0 (scratch)
- **DPX**: DPX2 (scratch)
- **PS**: `COUNT` location (4 words reserved via `$VAL`)

**Cross-references**: Called by `EXTASK`

---

### Module: TRAP — "TRAP HANDLER" (lines 573-630)

**$TITLE**: `TRAP`  
**$ENTRY**: `TRAP,0`  
**$EXT**: `INTEXT`  

**Purpose**: Handles trap (SVC) interrupts. Loads TMA and DPX0-3 from the current task's TCB save area, does `JSRT` to the SVC address, then stores DPX0-3, SP0, and SPFN back into the TCB.

**AP State Manipulated**:
- **S-Pad**: SP0, SP1, SP7 (scratch; SP7 = current TCB address on entry)
- **DPX**: DPX0-3 (loaded from TCB, used as SVC parameters, stored back)
- **TMA**: Loaded from TCB's `TMAREG` field (SVC address)
- **MD**: TCB fields (`TMAREG`, `DPX0`-`DPX3`, `SPFUNC`)

**Calling Convention**: The user's last instruction before the trap must be:
```
TRAP; DB=@XXX; LDTMA
```
where XXX is an SVC name (address). The SVC receives parameters in DPX0-3.

**Cross-references**: Calls `INTEXT`

---

### Module: FATAL/FPE — "FATAL/EXCEPTION INTERRUPT HANDLER" (lines 631-670)

**$TITLE**: `FATAL`  
**$ENTRY**: `FATAL,0`, `FPE,0`  
**$EXT**: `DELETE`, `INSERT`, `INTEXT`  
**$INSERT**: `COMSYS`

**Purpose**: Handles fatal and floating-point exception interrupts. Both result in abnormal termination: deletes the task from the ready queue and inserts it into the "morgue" queue.

**AP State Manipulated**:
- **S-Pad**: SP7 (scratch; = current TCB address on entry)
- **DPX**: DPX2-3 (parameters for DELETE/INSERT)
- **MD**: `MORGUE` queue header

**Cross-references**: Calls `DELETE`, `INSERT`, `INTEXT`

---

### Module: PRIQ — "PRIORITY INSERT INTO QUEUE" (lines 671-738)

**$TITLE**: `PRIQ`  
**$ENTRY**: `PRIQ,0`  
**$EXT**: `INSERT`

**Purpose**: Inserts a new element into a queue in priority order, before the first element of lower priority. Assumes queue header has priority 0.

**AP State Manipulated**:
- **S-Pad**: SP0-3 (scratch), SPFN (output = 0 if OK, non-0 if error)
- **DPX**: DPX0-3 (scratch; DPX2 = queue header, DPX3 = new element on input)

**Priority Comparison**: Uses `BLT` (branch if less than) to compare priorities. The loop traverses the queue comparing each element's priority against the new element's priority.

**Cross-references**: Calls `INSERT`

---

### Module: INSERT — "INSERT INTO QUEUE" (lines 739-775)

**$TITLE**: `INSERT`  
**$ENTRY**: `INSERT,0`  
**$EXT**: (none)

**Purpose**: Inserts a new element between "last" and "next" in a doubly-linked circular queue. Checks that the new element is not already linked elsewhere (RLINK must point to self).

**AP State Manipulated**:
- **S-Pad**: SP0-3 (scratch), SPFN (output = 0 if OK, non-0 if error)
- **DPX**: DPX2 (input = NEXT), DPX3 (input = NEW)

**Error Detection**: If `RLINK(NEW) != NEW`, the element is already linked elsewhere — returns with SP0 non-zero.

**Cross-references**: Called by `PRIQ`, `FATAL`/`FPE`

---

### Module: DEQ — "DEQUEUE" (lines 776-810)

**$TITLE**: `DEQ`  
**$ENTRY**: `DEQ,0`  
**$EXT**: (none)

**Purpose**: Unqueues the first element after a queue header. Returns the dequeued element's address or the header itself if empty.

**AP State Manipulated**:
- **S-Pad**: SP0-3 (scratch), SP0 (output = 0 if empty, non-0 if dequeued)
- **DPX**: DPX2 (input = queue header), DPX3 (output = dequeued element or header)

**Cross-references**: None within KERNEL.S

---

### Module: EMPTY — "CHECKS FOR EMPTY QUEUE" (lines 811-832)

**$TITLE**: `EMPTY`  
**$ENTRY**: `EMPTY,0`  
**$EXT**: (none)

**Purpose**: Checks if a queue has any elements. Returns the next element after the given header/element.

**AP State Manipulated**:
- **S-Pad**: SP0-1 (scratch), SPFN (output = 0 if empty)
- **DPX**: DPX2 (input = queue header), DPX3 (output = next element)

**Cross-references**: Called by `EXTASK`, `RTCINT`

---

### Module: DELETE — "DELETE FROM QUEUE" (lines 833-860)

**$TITLE**: `DELETE`  
**$ENTRY**: `DELETE,0`  
**$EXT**: (none)

**Purpose**: Deletes an element from a doubly-linked circular queue. Unlinks the element by updating its predecessor's RLINK and successor's LLINK, then sets the deleted element's links to point to itself.

**AP State Manipulated**:
- **S-Pad**: SP1-3 (scratch); SP0 is explicitly untouched
- **DPX**: DPX2 (output = next element), DPX3 (input = element to delete)

**Cross-references**: Called by `RTCINT`, `FATAL`/`FPE`

---

## 3. Key Routines — Detailed Analysis

### EXTASK — Task Scheduler

**Calling Convention**:
- **Input**: DPX(2) = ready queue header address
- **Output**: SPAD 0 and SMA = end of minimal save area in new task's TCB
- **Scratch**: SP0-1, SP5-7; DPX2-3
- **Return**: Does NOT return normally — jumps to `MNREST` which performs `RETURN; EXINT` to start the task

**AP Architectural Side Effects**:

| Resource | Read | Written |
|----------|------|---------|
| SP0 | — | End of min save area |
| SP1 | — | Scratch |
| SP5 (LAST) | — | Last full-context task TCB |
| SP6 (NEW) | — | New task TCB |
| SP7 (CUR) | — | Current task TCB |
| DPX2 | RDYQUE | — |
| DPX3 | — | TCB from EMPTY, overlay table ptr |
| MD: CURTSK | Current task TCB | New task TCB |
| MD: NEWTSK | New task TCB | — |
| MD: LSTFUL | Last full-context TCB | Updated if needed |
| MD: STATUS | Task status word | — |
| MD: OVLPTR | Overlay map pointer | — |
| MD: MINTCB | Min save area offset | — |
| MD: MAXTCB | Max save area offset | — |
| MD: CXTBIT | Context bit mask | — |

**Cross-references**:
- Calls: `EMPTY` (get highest-priority TCB), `CHKPT` (check for pending interrupts), `IDLE` (idle when no tasks), `PSMNGR` (ensure overlay residency), `MXSAVE` (save full context), `MXREST` (restore full context), `MNREST` (load minimal state)
- Called by: `INTEXT`

**Optimization — LSTFUL**: The `LSTFUL` (last full-context task) mechanism avoids redundant full context saves. If the new task was the last one to have full context saved, and no other full-context task has run since, the save is skipped.

**Timing** (from source comments):
- **Minimum** (same task): 48 cycles (24 EXTASK + 5 EMPTY + 15 PSMNGR + 4 CHKPT)
- **Maximum** (different task, full context): 377-389 cycles

---

### PSMNGR — PS Manager

**Calling Convention**:
- **Input**: DPX(3) = address of first overlay table entry; DPX(2) = number of entries
- **Output**: DPX(3) points within first OVTAB entry (at the residency word)
- **Scratch**: SP0-6; DPX0-3
- **Return**: Normal `RETURN`

**AP Architectural Side Effects**:

| Resource | Read | Written |
|----------|------|---------|
| SP0-6 | — | Scratch |
| DPX0-3 | Parameters | Modified |
| MD: Overlay table | Residency words, segment info | Residency bits |
| MD: SYSPTR | System save area pointer | — |
| PS | — | Code segments via MOVER |

**Key Algorithm**:
1. Loop through all overlay segments checking if `SHOULD_BE_RES == IS_RES`
2. If mismatch found, locate the segment's PS partition(s)
3. For each partition, mark the old segment (if any) as non-resident
4. Mark the new segment as resident
5. Call `MOVER` to transfer code
6. Restart from step 1 (in case of interruption)

**Cross-references**:
- Calls: `MOVER`
- Called by: `EXTASK`, `IO`

---

### MOVER — Code Mover

**Calling Convention**:
- **Input**: DPX(0) = PS address; DPX(1) = MD address; DPX(2) = number of PS words
- **Scratch**: SP0; DPX0-2; TMA
- **Return**: Normal `RETURN`

**AP Architectural Side Effects**:

| Resource | Read | Written |
|----------|------|---------|
| SP0 | — | Counter |
| DPX0-2 | Parameters | Modified |
| TMA | — | PS address pointer |
| MA | — | Switched to user MA |
| APSTAT | — | `CLRMOD`, `ION`, `ENTINT` |
| MD | Source data | — |
| PS | — | Destination data |

**Pipeline Exploitation**: The loop uses a 3-instruction, 5-cycle structure where:
- Column 1: `INCMA` (increment MD address) paired with `LPSRT`/`LPSLT` (store to PS)
- Column 2: `INCTMA` (increment PS address) paired with `DEC CTR` (decrement counter)
- The comment explicitly notes that `INCMA` and the PS load happen in the same cycle

**Cross-references**:
- Called by: `PSMNGR`

---

### IO — I/O Interrupt Handler

**Calling Convention**:
- **Input**: SPAD 7 = current task's TCB address
- **Scratch**: SP0-4, SP7; DPX0-3; DA
- **Return**: Does NOT return normally — jumps to `INTEXT`

**AP Architectural Side Effects**:

| Resource | Read | Written |
|----------|------|---------|
| SP0-4 | — | Scratch |
| SP7 | Current TCB | — |
| DPX0-3 | — | Parameters for PSMNGR, ISR |
| DA: IMASK | Current mask | Updated mask |
| DA: INBS | Interrupt status | — |
| MD: CONFIG | Device table entries | — |
| MD: SYSPTR | System save area | — |
| MD: LOGIOD | Spurious int count | Incremented |
| APSTAT | — | `IOINTA`, `CLRMOD`, `ENTINT` |

**IMASK Management**: The handler carefully reconstructs the IMASK after ISR return:
```
NEW_IMASK = (CURRENT_IMASK AND NOT PRI_MASK) OR RETURNED_BIT_MASK OR OLD_IMASK
```

**Cross-references**:
- Calls: `RTCINT`, `RMVCLK`, `PSMNGR`, `INTEXT`
- Called by: `CHKPT`

---

### INTEXT — Interrupt Exit

**Calling Convention**:
- **Input**: (implicit) `SYSPTR` and `SYSAVE` in MD
- **Output**: SPAD 0 = SYSPTR - 1 (for MNREST)
- **Scratch**: SP0-1
- **Return**: Does NOT return — jumps to `EXTASK` or `MNREST`

**AP Architectural Side Effects**:

| Resource | Read | Written |
|----------|------|---------|
| SP0 | — | SYSPTR-1 |
| SP1 | — | SYSAVE |
| MD: SYSPTR | Current system pointer | — |
| MD: SYSAVE | System save area base | — |

**Decision Logic**:
- `SYSPTR == SYSAVE` → came from user task → go to `EXTASK`
- `SYSPTR != SYSAVE` → came from ISR/PSMNGR → go to `MNREST`

**Cross-references**:
- Calls: `EXTASK`, `MNREST`
- Called by: `IO`, `TRAP`, `FATAL`/`FPE`

---

### RTCINT — RTC Interrupt Handler

**Calling Convention**:
- **Input**: (implicit) `CLKQUE` in MD
- **Output**: DPX(1) = TCB address; SPAD 0 and SPFN = 0 if queue empty, TCB addr otherwise
- **Scratch**: SP0-4; DPX0-3
- **Return**: Normal `RETURN`

**AP Architectural Side Effects**:

| Resource | Read | Written |
|----------|------|---------|
| SP0-4 | — | Scratch |
| SPFN | — | Queue status |
| DPX0-3 | — | Parameters for DELETE, RESUME |
| MD: CLKQUE | Clock queue header | — |
| MD: TCB fields | RCLOCK, DPX0, SPFUNC, TYPE | DPX0, SPFUNC, SP0 |
| MD: Exchange TYPE | — | Set to EMPTY if needed |

**Cross-references**:
- Calls: `EMPTY`, `DELETE`, `RESUME`
- Called by: `IO`

---

## 4. Architectural Insights

### 4.1 The SYSPTR/SYSAVE Context Distinction

The most subtle architectural feature revealed is the **system save area stack** mechanism. `SYSPTR` points to the current top of the system save area, while `SYSAVE` is its base. When a user task is running, `SYSPTR == SYSAVE` (the save area is "empty"). When an interrupt occurs, the state is saved and `SYSPTR` is incremented. Nested interrupts push further. `INTEXT` uses this comparison to determine whether to return to a task (via `EXTASK`) or to an interrupted ISR/PSMNGR (via `MNREST`).

This implies the AP-120B's interrupt hardware does NOT automatically distinguish between user and supervisor mode interrupts — the software must track this via the save area pointer.

### 4.2 Two-Level Context Management

The kernel implements a **hierarchical context save**:
- **Minimal context** (`MNREST`): Saves/restores only the state needed to resume a task (S-Pad, DPX, TMA, etc.) — stored at the end of the TCB's min save area
- **Full context** (`MXSAVE`/`MXREST`): Saves/restores all registers including the full data pad — stored in a separate max save area

The `LSTFUL` optimization tracks which task last had its full context saved. If the same task is being resumed, the full save/restore is skipped entirely.

### 4.3 Overlay System Architecture

The PS overlay system is remarkably sophisticated for 1979:
- **8-word overlay table entries** with segment number, MD/PS addresses, length, task ID, residency bits, and partition table pointer
- **Residency tracking** uses two bits per segment: "should be resident" (LM bit) and "currently resident" (EXP bit)
- **Partition table** allows one segment to span multiple PS partitions
- **MOVER** handles the 2:1 MD-to-PS word compression with a carefully pipelined loop

### 4.4 Interrupt Priority Management

The I/O handler implements a **priority-based interrupt masking** scheme:
- Each device has a priority mask that blocks itself and all lower-priority devices
- The IMASK register is saved before ISR execution and restored (with modifications) after
- The ISR can return a bit mask to enable/disable further interrupts from its device
- RTC (device 5) is handled as a special case with its own code path

### 4.5 Queue Architecture

All queues are **doubly-linked circular lists** with a header element. The header's RLINK points to the first element, and LLINK to the last. Key operations:
- `EMPTY`: Checks if header's RLINK points to itself
- `INSERT`: Links new element between LAST and NEXT, with error checking
- `DELETE`: Unlinks element, sets its links to self (for error detection)
- `DEQ`: Removes first element after header
- `PRIQ`: Priority insertion using `BLT` comparison

### 4.6 Trap/SVC Mechanism

The trap handler implements a **register-windowed SVC call**:
1. User executes `TRAP; DB=@SVC_ADDR; LDTMA`
2. Hardware saves minimal state, loads TMA with SVC address
3. Trap handler loads DPX0-3 from TCB save area (user's parameters)
4. Does `JSRT` to SVC (jump to TMA address)
5. On return, stores DPX0-3, SP0, SPFN back to TCB
6. Exits via `INTEXT`

This means SVCs receive parameters in DPX0-3 and can return results in the same registers.

## 5. Design Observations

### 5.1 Performance Optimization Patterns

1. **Fast-path detection**: `EXTASK` checks `NEWTSK == CURTSK` first — if same task, skips all context save/restore (48 cycles minimum)

2. **LSTFUL optimization**: Avoids redundant full context saves by tracking which task last had full context saved

3. **Inline queue operations**: Queue primitives are separate subroutines (not macros) but are called frequently — the 5-cycle `EMPTY` is the most heavily used

4. **Pipeline-aware coding**: The `MOVER` loop is explicitly documented to exploit the AP-120B's dual-column execution, with careful cycle counting

5. **Register allocation**: S-Pad registers are assigned meaningful names via equates, and the comments document which are scratch vs. parameter

### 5.2 Memory Efficiency Patterns

1. **Fixed-offset TCB layout**: All TCB fields are accessed via named offsets (e.g., `RCLOCK`, `DPX0`, `SPFUNC`, `TMAREG`), enabling fast indexed access

2. **Overlay table compaction**: 8-word entries pack all segment management information, with residency bits in a single word

3. **PS residency tracking**: Uses `WRTLMN` instruction for atomic updates to overlay table residency words

4. **System save area stack**: Single save area with pointer (`SYSPTR`) handles nested interrupts without per-task save areas

### 5.3 1979 Coding Idioms

1. **`MOV R0,R0; SETMA`**: No-op pattern used for pipeline synchronization — the `MOV` sets condition codes while `SETMA` sets the memory address

2. **`STATMA`**: Used to stall for memory access completion — the status is loaded into MA

3. **`LDSPE`/`ADD R6`**: Pattern to adjust for sign-extended loads from `LDSPE` (load S-Pad with extension). The constant 512 (octal 1000) compensates for sign extension

4. **`DPX<ZERO`**: Clear DPX register via the `DPX<` syntax

5. **`BR .+2`**: Skip next instruction (relative branch)

6. **`INCMA`/`DECMA`**: Auto-increment/decrement memory address — heavily used for sequential access

7. **`MI<SPFN`**: Store S-Pad to memory with implied MA increment

### 5.4 Error Handling and Resilience

1. **Spurious interrupt detection**: `IO` handler counts fake interrupts in `LOGIOD`

2. **Queue integrity checks**: `INSERT` verifies new element is unlinked before insertion

3. **Abnormal termination**: `FATAL`/`FPE` handlers move tasks to "morgue" queue rather than crashing

4. **PSMNGR re-check**: After code transfer, all segments are re-checked in case the process was interrupted

5. **Idle counting**: `IDLE` maintains a counter in PS for diagnostic purposes

### 5.5 Documentation Practices

The source code is exceptionally well-documented for 1979:
- **Timing analysis**: Every routine has documented cycle counts for various paths
- **Register usage**: Explicit "SCRATCH" lists for each routine
- **Parameter documentation**: Clear (IN)/(OUT) annotations
- **Algorithm descriptions**: Procedural comments at the start of each module
- **Assumptions stated**: "This assumes SUP. MODE, SMA, AND INTS. OFF" appears consistently

### 5.6 Cross-Module Data Flow

The kernel's data structures are defined in `COMSYS` and `SYSDEF` (not shown), but the usage reveals:
- **Global MD locations**: `CURTSK`, `NEWTSK`, `LSTFUL`, `RDYQUE`, `CLKQUE`, `MORGUE`, `SYSPTR`, `SYSAVE`, `LOGIOD`, `INBS`, `CONFIG`
- **TCB offsets**: `STATUS`, `OVLPTR`, `MINTCB`, `MAXTCB`, `CXTBIT`, `RCLOCK`, `DPX0`, `SPFUNC`, `TMAREG`, `TYPE`
- **Overlay table offsets**:

### GLM final

(adv 57s, 8446c)

### **KERNEL.S Analysis — Core Mini-100/Super-100 Kernel**

---

#### **1. Subsystem Overview**  
`KERNEL.S` implements the **real-time scheduler, interrupt dispatcher, and memory manager** for the FPS-100’s AP-side supervisor (Mini-100/Super-100). It provides:  
- **Priority-based task scheduling** (via `EXTASK`)  
- **Program Store (PS) overlay management** (via `PSMNGR`/`MOVER`)  
- **Interrupt handling** (I/O, RTC, traps, fatal errors)  
- **Doubly-linked queue operations** for task state management  
- **Supervisor-call (SVC) and trap dispatch**  

This subsystem manages task transitions between READY, RUNNING, SLEEPING, and TERMINATED states, ensuring deterministic PS residency for code segments.

---

#### **2. Per-File Purpose**  
All routines are in `KERNEL.S` with distinct `$TITLE` entries:  

| Routine      | $ENTRY       | $EXT Dependencies          | Purpose | AP State Manipulation |  
|--------------|-------------|---------------------------|---------|----------------------|  
| **EXTASK**   | EXTASK,0    | EMPTY, CHKPT, IDLE, MXSAVE, MNREST, MXREST, PSMNGR | Scheduler: selects highest-priority task, manages residency, switches context | CURTSK, NEWTSK, LSTFUL, RDYQUE, TCB STATUS fields; DPX(2-3) for queues; SMA for context save areas |  
| **PSMNGR**   | PSMNGR,0    | MOVER                      | PS memory residency: manages overlay segment loading, marks non-resident segments, triggers MD→PS transfer | Overlay table entries (8-word format), PS partition tables; DPX(0-3) for partition traversal |  
| **MOVER**    | MOVER,0     | -                         | MD→PS code transfer (2 MD words = 1 PS word), switches to user mode during transfer | TMA for PS addressing; SELMA/CLRMOD for mode switching; 5-cycle/word loop |  
| **IO**       | IO,0        | RMVCLK, PSMNGR, RTCINT, INTEXT | I/O interrupt handler: identifies device, masks interrupts, ensures ISR residency, dispatches via JSRT | INBS, IMASK, APST3; `$COMMON /CONFIG/` device table; DA for IMASK updates |  
| **INTEXT**   | INTEXT,0    | EXTASK, MNREST            | Interrupt exit dispatcher: routes to EXTASK (user) or restores state (ISR/PSMNGR) | SYSPTR, SYSAVE to determine return path |  
| **RTCINT**   | RTCINT,0    | EMPTY, DELETE, RESUME     | RTC handler: dequeues timed tasks, sends timeout messages, resumes to ready queue | CLKQUE, TCB RCLOCK/DPX0/SPFN links; exchange type manipulation |  
| **CHKPT**    | CHKPT,0     | IO                        | Interrupt checkpoint: checks APSTAT3 for pending interrupts, clears SRA bits | APST3 (mask 0o176077); SP7=CURTSK |  
| **IDLE**     | IDLE,0      | -                         | Idle loop: increments PS-resident idle counter when no tasks ready | COUNT in PS (via RPSL/LPSL) |  
| **TRAP**     | TRAP,0      | INTEXT                    | Trap handler: loads TMA/DPX0-3 from TCB, JSRT to SVC, stores registers back | TCB TMAREG/DPX0/SPFUNC offsets |  
| **FATAL**    | FATAL,0<br>FPE,0 | DELETE, INSERT, INTEXT | Fatal/FPE handler: terminates task, moves to MORGUE queue | READY queue, MORGUE exchange via DELETE/INSERT |  
| **PRIQ**     | PRIQ,0      | INSERT                    | Priority queue insertion: inserts task before first lower-priority element | Queue priority fields (offset 2 from TCB) |  
| **INSERT**   | INSERT,0    | -                         | Doubly-linked list insertion: checks self-pointer to detect linked elements | RLINK/LLINK fields; error code in SP0/SPFN |  
| **DEQ**      | DEQ,0       | -                         | Dequeue: removes first element from queue header | RLINK/LLINK; SP0=0 if empty |  
| **EMPTY**    | EMPTY,0     | -                         | Queue empty check: returns next element or header | RLINK from given element |  
| **DELETE**   | DELETE,0    | -                         | Element deletion: updates neighbor links | RLINK/LLINK; returns successor in DPX(2) |  

---

#### **3. Key Routines**  
##### **EXTASK (Scheduler)**  
- **Calling Convention**: Supervisor mode, SMA, interrupts off. No explicit parameters.  
- **Side Effects**:  
  - Reads/writes CURTSK, NEWTSK, LSTFUL, RDYQUE, TCB STATUS.  
  - S-Pad: STAT=0, FULLC=1, HERE=0, LAST=5, NEW=6, CUR=7.  
  - DPX(2)=RDYQUE, DPX(3)=TCB address.  
- **Cross-refs**: Calls EMPTY, CHKPT, IDLE, MXSAVE, MXREST, MNREST, PSMNGR.  
- **Timing**: 48 cycles (min) → 377-389 cycles (max).  

##### **PSMNGR (PS Manager)**  
- **Calling Convention**: DPX(3)=overlay table pointer, DPX(2)=segment count.  
- **Side Effects**:  
  - Reads/writes 8-word overlay entries (segment#/MD addr/PS addr/length/task ID/residency/partition ptr/entry count).  
  - Toggles residency bits (RES word, bit 6).  
- **Cross-refs**: Calls MOVER only.  
- **Critical Insight**: PS is partitioned; segments not marked "should-be-resident" (bit 6) are evicted.  

##### **MOVER (Code Transfer)**  
- **Calling Convention**: DPX(0)=PS addr, DPX(1)=MD addr, DPX(2)=PS word count.  
- **Side Effects**:  
  - Switches to user mode (`CLRMOD`), enables interrupts (`ION`).  
  - 3-instruction loop:  
    ```apal  
    INCMA;         | LPSRT; DB=MD  
    INCMA; INCTMA; | DEC CTR; BGT LOOP  
    LPSLT; DB=MD; |  
    ```  
  - Returns via `ENTINT` (supervisor mode).  

##### **IO (I/O Interrupt Handler)**  
- **Calling Convention**: SP7=CURTSK.  
- **Side Effects**:  
  - Reads INBS for device number, IMASK via DA.  
  - Uses `$COMMON /CONFIG/` for device priority masks/ISR pointers.  
  - Calls PSMNGR to load ISRs.  
  - Dispatches ISR via `JSRT` (user mode), restores IMASK on exit.  
- **Critical Insight**: APSTAT3 (0o176077) must be cleared after interrupt acknowledgment.  

##### **RTCINT (RTC Handler)**  
- **Calling Convention**: R1=device number.  
- **Side Effects**:  
  - Modifies TCB DPX0/SPFN/SP0 with timeout message.  
  - Sets exchange type to EMPTY if TCB was sole element.  
- **Queue Logic**: Compares RLINK/LLINK to detect empty exchange.  

##### **Queue Operations**  
All use **doubly-linked lists** with RLINK (offset 0), LLINK (offset 1), and priority (offset 2):  
- **INSERT**: Checks self-pointer (error if linked).  
- **DELETE**: Updates neighbor links; returns successor.  
- **DEQ**: Dequeues from header; SP0=0 if empty.  
- **EMPTY**: Returns next element or header.  
- **PRIQ**: Traverses priority field (offset 2), inserts before lower priority.  

---

#### **4. Architectural Insights**  
- **Supervisor/User Mode**:  
  - `MOVER` and `IO` use `CLRMOD`/`ION` for user mode during ISR/PS transfer.  
  - `ENTINT` reverts to supervisor mode with SMA.  
- **Interrupt Handling**:  
  - APSTAT3 contains SRA bits cleared after `IOINTA`.  
  - Device configuration table maps INBS numbers to priority masks/ISRs.  
- **Context Management**:  
  - **Minimal State** (MINTCB): Saved/restored by MNREST for all task switches.  
  - **Full Context** (MAXTCB): Saved/restored by MXSAVE/MXREST only when switching between full-context tasks.  
- **PS Memory**:  
  - Overlays use 8-word entries; residency bit (bit 6) tracks "should-be" vs. "currently" resident.  
  - MOVER transfers 2 MD words per PS word in a 5-cycle loop.  

---

#### **5. Design Observations**  
- **Performance Optimization**:  
  - **Minimal Path**: EXTASK minimizes context switches (48 cycles) via `SETMA; MI<DPX(3)` for same-task resumes.  
  - **Loop Unrolling Avoidance**: MOVER’s 3-instruction loop achieves 5 cycles/word via paired instructions.  
  - **Early Exit**: PSMNGR skips partition management if all segments are already resident.  
- **APAL Idioms**:  
  - **Two-Column Execution**: Used for memory timing (e.g., `INCMA; LPSRT` across columns).  
  - **STATMA**: Forces memory access timing in critical paths.  
  - **Self-Pointer Checks**: INSERT detects linked elements via `RLINK` pointing to self.  
- **Memory Layout**:  
  - TCB fields: RLINK(0)/LLINK(1)/PRIORITY(2)/DPX0/SPFUNC/STATUS/CXTBIT.  
  - Overlay entry: Segment#/MD addr/PS addr/Length/TaskID/Residency/Ptr/Count.  
- **Error Handling**:  
  - FATAL/FPE: Aborts task, moves to MORGUE queue.  
  - Spurious I/O: Counted in LOGOID but ignored.  
- **Timing Discipline**:  
  - Comments specify exact cycle counts (e.g., EXTASK: 48–389 cycles), reflecting real-time guarantees.  

--- 
This analysis reveals a tightly integrated scheduler/RTOS kernel designed for deterministic performance on the 1979-vintage FPS-100, with intricate memory management and interrupt handling optimized for hard real-time constraints.

<details><summary>Cooperative drafts</summary>

#### DS coop

# KERNEL.S — Core Mini-100/Super-100 Kernel Analysis

## 1. Subsystem Overview

KERNEL.S implements the **core task scheduler and interrupt dispatcher** for the FPS-100's AP-side supervisor (Super-100/Mini-100). It provides:

- **Task scheduling** — priority-based round-robin via `EXTASK`
- **Program Store (PS) memory management** — overlay loading via `PSMNGR` and `MOVER`
- **Interrupt handling** — I/O, RTC, trap, and fatal exception dispatch
- **Queue management** — doubly-linked list operations for TCB scheduling

This is the heart of the AP-side RTOS, managing all task state transitions and PS residency.

## 2. Per-File Purpose

### EXTASK (lines 1-96)
- **$TITLE**: EXTASK
- **$ENTRY**: EXTASK,0
- **$EXT**: EMPTY, CHKPT, IDLE, MXSAVE, MNREST, MXREST, PSMNGR
- **Purpose**: Main scheduler — selects highest-priority ready task, makes it PS-resident if needed, saves/restores full context if task changed, then loads minimum state and runs the task.
- **AP state**: Reads/writes CURTSK, NEWTSK, LSTFUL, RDYQUE, STATUS fields in TCBs. Uses DPX(2-3) for queue operations. Sets SMA for context save/restore areas.

### PSMNGR (lines 97-237)
- **$TITLE**: PSMNGR
- **$ENTRY**: PSMNGR,0
- **$EXT**: MOVER
- **Purpose**: Manages PS (Program Store) memory residency. Checks overlay table entries for each task segment, marks old segments non-resident, marks new segments resident, and calls MOVER to transfer code from MD to PS.
- **AP state**: Reads/writes overlay table entries in MD. Uses DPX(0-3) for partition table traversal. Calls MOVER for code transfer.

### MOVER (lines 238-283)
- **$TITLE**: MOVER
- **$ENTRY**: MOVER,0
- **Purpose**: Transfers code from MD to PS (2 MD words = 1 PS word). Switches to user mode with interrupts enabled during transfer, then back to supervisor mode.
- **AP state**: Uses TMA for PS addressing, SELMA/CLRMOD for mode switching, ION/ENTINT for interrupt control. 3-instruction, 5-cycle loop.

### IO (lines 284-393)
- **$TITLE**: IO
- **$ENTRY**: IO,0
- **$EXT**: RMVCLK, PSMNGR, RTCINT, INTEXT
- **Purpose**: I/O interrupt handler — identifies interrupting device, masks further interrupts, ensures ISR is PS-resident, calls ISR via JSRT, then restores interrupt mask on return.
- **AP state**: Reads INBS, IMASK, APST3. Uses device configuration table ($COMMON /CONFIG/). Manipulates DA register for IMASK output.

### INTEXT (lines 394-424)
- **$TITLE**: INTEXT
- **$ENTRY**: INTEXT,0
- **$EXT**: EXTASK, MNREST
- **Purpose**: Common interrupt exit — determines origin (user task, ISR, or PSMNGR) and either returns to EXTASK or restores saved state via MNREST.
- **AP state**: Reads SYSPTR, SYSAVE to determine return path.

### RTCINT (lines 425-492)
- **$TITLE**: RTCINT
- **$ENTRY**: RTCINT,0
- **$EXT**: EMPTY, DELETE, RESUME
- **Purpose**: RTC interrupt handler — gets first element from clock queue, deletes task from exchange, sends timeout message, and resumes task to ready queue.
- **AP state**: Manipulates CLKQUE, TCB links (RCLOCK offset), exchange type field, and TCB's DPX0/SPFN/SP0 fields for timeout message.

### CHKPT (lines 493-517)
- **$TITLE**: CHKPT
- **$ENTRY**: CHKPT,0
- **$EXT**: IO
- **Purpose**: Checkpoint — checks for pending interrupts, clears SRS bits in APSTAT3 if found, and dispatches to IO handler.
- **AP state**: Reads APST3, writes SRA bits (mask 176077 octal). Sets SP7 = CURTSK for IO.

### IDLE (lines 518-537)
- **$TITLE**: IDLE
- **$ENTRY**: IDLE,0
- **Purpose**: Idle routine — called when no tasks ready and no I/O pending. Maintains idle count in PS memory.
- **AP state**: Uses RPSL/LPSL for PS memory access. Increments COUNT in PS.

### TRAP (lines 538-588)
- **$TITLE**: TRAP
- **$ENTRY**: TRAP,0
- **$EXT**: INTEXT
- **Purpose**: Trap handler — loads TMA and DPX 0-3 from TCB save area, does JSRT to SVC, then stores DPX 0-3, SP0, SPFN back to TCB.
- **AP state**: Reads/writes TCB fields at TMAREG, DPX0, SPFUNC offsets. Uses JSRT for supervisor call dispatch.

### FATAL (lines 589-617)
- **$TITLE**: FATAL
- **$ENTRY**: FATAL,0 and FPE,0
- **$EXT**: DELETE, INSERT, INTEXT
- **Purpose**: Fatal/FPE interrupt handler — deletes task from ready queue, inserts into MORGUE queue (abnormal termination exchange).
- **AP state**: Manipulates ready queue and MORGUE exchange via DELETE/INSERT.

### PRIQ (lines 618-682)
- **$TITLE**: PRIQ
- **$ENTRY**: PRIQ,0
- **$EXT**: INSERT
- **Purpose**: Priority insert into queue — inserts new element before first element of lower priority. Queue header has priority 0.
- **AP state**: Traverses queue comparing priority fields (offset 2 from element). Calls INSERT when position found.

### INSERT (lines 683-716)
- **$TITLE**: INSERT
- **$ENTRY**: INSERT,0
- **Purpose**: Inserts new element between LAST and NEXT in doubly-linked list. Checks if new element is already linked (self-pointer check).
- **AP state**: Manipulates RLINK/LLINK fields. Returns error code in SP0/SPFN.

### DEQ (lines 717-750)
- **$TITLE**: DEQ
- **$ENTRY**: DEQ,0
- **Purpose**: Dequeues first element after queue header. Returns element address in DPX(3) or header if empty.
- **AP state**: Manipulates RLINK/LLINK. Returns empty status in SP0.

### EMPTY (lines 751-770)
- **$TITLE**: EMPTY
- **$ENTRY**: EMPTY,0
- **Purpose**: Checks if queue has successor element. Returns next element in DPX(3) and empty flag in SP0.
- **AP state**: Reads RLINK from given element address.

### DELETE (lines 771-795)
- **$TITLE**: DELETE
- **$ENTRY**: DELETE,0
- **Purpose**: Deletes element from doubly-linked list. Returns successor address in DPX(2).
- **AP state**: Manipulates RLINK/LLINK of element and its neighbors.

## 3. Key Routines

### EXTASK (scheduler)
- **Calling convention**: Called with supervisor mode, SMA, interrupts off. No explicit parameters — reads global state (RDYQUE, CURTSK, NEWTSK).
- **Returns**: Via MNREST which does `RETURN; EXINT` to start task running.
- **Side effects**:
  - Reads/writes: CURTSK, NEWTSK, LSTFUL, RDYQUE, STATUS fields
  - S-Pad usage: STAT=0, FULLC=1, HERE=0, LAST=5, NEW=6, CUR=7
  - DPX usage: DPX(2)=RDYQUE, DPX(3)=TCB address
- **Cross-refs**: Calls EMPTY, CHKPT, IDLE, MXSAVE, MXREST, MNREST, PSMNGR

### PSMNGR (PS manager)
- **Calling convention**: DPX(3)=overlay table entry pointer, DPX(2)=number of entries. Supervisor mode, SMA, interrupts off.
- **Returns**: DPX(3) pointing within first OVTAB entry at RES word.
- **Side effects**:
  - Reads/writes overlay table entries (8 words each)
  - Marks residency bits in RES word (bit 6)
  - Calls MOVER for code transfer
  - S-Pad: SEGENT=0, SEGCNT=1, WIDE=2, SHOULD=3, IS=4, CNT=5
- **Cross-refs**: Calls MOVER

### MOVER (code mover)
- **Calling convention**: DPX(0)=PS address, DPX(1)=MD address, DPX(2)=number of PS words
- **Returns**: Via RETURN after switching back to supervisor mode
- **Side effects**:
  - Switches to user mode (CLRMOD), enables interrupts (ION)
  - Uses TMA for PS addressing
  - 3-instruction loop: INCMA/LPSRT, INCMA/INCTMA+DEC CTR, LPSLT/BGT
  - Returns to supervisor mode via ENTINT
- **Cross-refs**: Called by PSMNGR only

### IO (I/O interrupt handler)
- **Calling convention**: Called from CHKPT with SP7=CURTSK. Supervisor mode, SMA, interrupts off.
- **Returns**: Via JMP INTEXT
- **Side effects**:
  - Reads INBS for device number
  - Reads/writes IMASK register via DA
  - Reads device configuration table ($COMMON /CONFIG/)
  - Calls PSMNGR to ensure ISR residency
  - Calls RTCINT for RTC interrupts
  - Uses JSRT to call ISR in user mode
- **Cross-refs**: Calls RTCINT, PSMNGR, INTEXT, RMVCLK

### RTCINT (RTC handler)
- **Calling convention**: Called from IO with R1=device number. Supervisor mode, interrupts off.
- **Returns**: DPX(1)=TCB address, SP0/SPFN=0 if queue empty, TCB addr otherwise
- **Side effects**:
  - Reads CLKQUE, TCB links (RCLOCK offset)
  - Sets exchange type to EMPTY if TCB was only element
  - Stores timeout message in TCB's DPX0, SPFN, SP0
  - Calls DELETE, RESUME
- **Cross-refs**: Calls EMPTY, DELETE, RESUME

### CHKPT (checkpoint)
- **Calling convention**: Called with supervisor mode, interrupts off
- **Returns**: Via RETURN if no interrupts, JMP IO+1 if interrupt pending
- **Side effects**:
  - Reads APST3, clears SRA bits (mask 176077 octal)
  - Sets SP7=CURTSK for IO
- **Cross-refs**: Calls IO

### TRAP (trap handler)
- **Calling convention**: Called with SP7=TCB address. Supervisor mode, interrupts off.
- **Returns**: Via JMP INTEXT
- **Side effects**:
  - Loads TMA, DPX 0-3 from TCB save area
  - Does JSRT to SVC
  - Stores DPX 0-3, SP0, SPFN back to TCB
- **Cross-refs**: Calls INTEXT

### Queue operations (INSERT, DELETE, DEQ, EMPTY, PRIQ)
- **Common convention**: All assume doubly-linked lists with RLINK at offset 0, LLINK at offset 1
- **INSERT**: DPX(2)=NEXT, DPX(3)=NEW. Checks NEW's RLINK points to self (unlinked).
- **DELETE**: DPX(3)=element to delete. Returns DPX(2)=successor.
- **DEQ**: DPX(2)=queue header. Returns DPX(3)=element or header if empty.
- **EMPTY**: DPX(2)=element/header. Returns DPX(3)=next, SP0=0 if empty.
- **PRIQ**: DPX(2)=queue header, DPX(3)=new element. Priority at offset 2.

## 4. Architectural Insights

### Supervisor Mode Management
The code reveals a sophisticated supervisor/user mode switching mechanism:
- **MOVER** switches to user mode (`CLRMOD`) with interrupts enabled (`ION`) during PS transfers, then back via `ENTINT`
- **IO** uses `CLRMOD` + `SELMA` before `JSRT` to ISR, then `ENTINT` on return
- This suggests the AP-120B supports at least two privilege levels with separate MA (Memory Address) registers

### Interrupt Handling Architecture
The interrupt system is more complex than documented:
- **APSTAT3** (address 176077 octal) contains SRA bits that must be cleared after interrupt acknowledgment
- **INBS** register provides device number on interrupt
- **IMASK** register (accessed via DA) provides priority-based interrupt masking
- The device configuration table ($COMMON /CONFIG/) maps device numbers to priority masks, bit masks, and ISR overlay pointers

### Context Save/Restore
The code reveals three levels of context:
1. **Minimum state** (MINTCB offset) — saved/restored by MNREST for every task switch
2. **Full context** (MAXTCB offset) — saved/restored by MXSAVE/MXREST only when switching between tasks that both have full context
3. **System save area** (SYSAVE/SYSPTR) — used for interrupt handling, with stack-like behavior

### PS Memory Management
The overlay system is sophisticated:
- Each task has an **overlay table** with 8-word entries per segment
- PS is divided into **partitions** tracked by partition table entries
- The residency word (offset 6) has two bits: "should be resident" and "currently resident"
- MOVER transfers 2 MD words per PS word in a 3-instruction, 5-cycle loop

### Queue Implementation
Doubly-linked lists use a **header element** that is always present:
- RLINK at offset 0, LLINK at offset 1
- Empty queue: header's RLINK = header's LLINK = header itself
- Priority field at offset 2 (used by PRIQ)
- Self-pointer check (RLINK points to self) indicates element is unlinked

## 5. Design Observations

### Performance Optimization Patterns

1. **Minimal path optimization**: EXTASK's timing comments show 48 cycles minimum vs 377-389 maximum — the code is structured for the common case (same task continues)

2. **Loop unrolling avoidance**: MOVER uses a 3-instruction loop with careful instruction pairing to achieve 5 cycles per PS word

3. **Early exit**: PSMNGR checks all segments first, only entering the expensive partition management when a mismatch is found

4. **Register allocation**: S-Pad registers are reused across routines with clear scratch conventions documented in comments

### APAL Idioms

1. **Two-column instruction format**: The code uses APAL's dual-column execution model extensively:
   ```apal
   INCMA;                         "GET 1ST 1/2 OF NTH PS WORD
        LPSRT; DB=MD              "STORE 2ND 1/2 OF (N-1)TH PS WORD
   ```

2. **STATMA pattern**: Used to force memory access timing:
   ```apal
   LDSPI R2; DB=RES-1
   ADD R2,SEGENT; SETMA;
        DPX(3)<SPFN;
   ```

3. **Self-modifying code avoidance**: Constants like `COUNT` in IDLE use `$VAL` directives for PS-resident data

4. **Error return via SP0/SPFN**: Queue operations return status in both SP0 and SPFN for efficient testing

### Memory Layout Conventions

1. **TCB structure** (inferred from offsets):
   - Offset 0: RLINK (queue linkage)
   - Offset 1: LLINK (queue linkage)
   - Offset 2: Priority
   - Various offsets for DPX0, TMAREG, SPFUNC, STATUS, CXTBIT
   - MINTCB/MAXTCB for context save areas

2. **Overlay table entry** (8 words):
   - Word 1: Overlay segment number
   - Word 2: MD address
   - Word 3: PS address
   - Word 4: Length (PS words)
   - Word 5: Task ID/TCB address
   - Word 6: Residency flags
   - Word 7: PS partition table pointer
   - Word 8: Number of PS partition entries

3. **Device configuration table** (5 words per device):
   - Word 1: Priority mask
   - Word 2: Bit mask
   - Word 3: Overlay table entry pointer
   - Word 4: Device order number (EXP) / Physical address (LMAN)
   - Word 5: Old IMASK save area

### Error Handling Philosophy

- **FATAL/FPE**: Tasks are terminated abnormally and moved to MORGUE queue
- **INSERT**: Returns error if element already linked (self-pointer check)
- **Spurious interrupts**: Counted in LOGIOD but otherwise ignored
- **Empty queues**: Handled gracefully with zero/non-zero return flags

### Timing Discipline

The extensive timing comments (48 cycles, 377-389 cycles, etc.) reveal:
- FPS engineers counted cycles precisely for real-time guarantees
- Different paths have documented minimum/maximum timings
- The scheduler is designed for deterministic behavior in hard real-time contexts

#### GLM coop

### 1. Subsystem Overview
This `KERNEL.S` implements the core task scheduler and interrupt-handling subsystem for the Super-100/Mini-100 supervisor running on the AP-120B. It manages:
- Task scheduling (priority-based selection/residency)
- Context switching (minimal/full save/restore)
- Memory overlay management (MD⇄PS transfers)
- Interrupt dispatching (I/O, RTC, traps, exceptions)
- Queue operations (ready/clock/task state queues)

### 2. Per-File Purpose
**KERNEL.S** (1216 lines)
- **Title**: "EXECUTE TASK MODULE" (primary), "PS MANAGER", "CODE MOVER", etc.
- **Public Entries**:
  - `EXTASK`: Main task scheduler
  - `PSMNGR`: PS overlay residency manager
  - `MOVER`: Code mover from MD to PS
  - `IO`: I/O interrupt handler
  - `INTEXT`: Common interrupt exit
  - `RTCINT`: RTC interrupt handler
  - `CHKPT`: Interrupt checkpoint
  - `IDLE`: Idle routine
  - `TRAP`: Trap/SVC handler
  - `FATAL`/`FPE`: Exception handlers
  - `PRIQ`/`INSERT`/`DEQ`/`EMPTY`/`DELETE`: Queue operations
- **Externals**:
  - `EMPTY`, `CHKPT`, `IDLE`, `MXSAVE`, `MNREST`, `MXREST`, `PSMNGR`
  - `MOVER`, `RMVCLK`, `RTCINT`, `INTEXT`, `DELETE`, `RESUME`
- **Purpose**: Core scheduler and interrupt dispatcher
- **State Manipulation**: 
  - S-PAD: SP0-7 (scratch/parameters), SPFN (status flags)
  - DPX: DPX0-3 (queue headers/parameters)
  - MD: TCBs, overlay tables, system queues
  - APSTAT: Interrupt masking, control bits
  - PS: Overlay residency via PSMNGR/MOVER

### 3. Key Routines
**EXTASK** (Task Scheduler)
- **Convention**: 
  - Input: DPX(2)=ready queue header
  - Output: SPAD 0/SMA = end of min save area
  - Scratch: SP 0-1,5-7; DPX 2-3
- **Side Effects**:
  - Modifies CURTSK/NEWTSK in MD
  - Calls MXSAVE/MXREST for full context
  - Calls MNREST to load minimal context
- **Cross-references**: Calls EMPTY, CHKPT, IDLE, MXSAVE, MXREST, MNREST, PSMNGR

**PSMNGR** (PS Manager)
- **Convention**:
  - Input: DPX(3)=overlay table addr, DPX(2)=entry count
  - Output: DPX(3) points to first segment's residency word
  - Scratch: SP 0-6; DPX 0-3
- **Side Effects**:
  - Modifies overlay residency bits
  - Calls MOVER for MD→PS transfers
- **Cross-references**: Calls MOVER

**MOVER** (Code Transfer)
- **Convention**:
  - Input: DPX(0)=PS addr, DPX(1)=MD addr, DPX(2)=word count
  - Scratch: SP 0; DPX 0-2; TMA
- **Side Effects**:
  - Switches to user mode/MA during execution
  - Transfers 2 MD words → 1 PS word
- **Cross-references**: Called by PSMNGR

**IO** (I/O Handler)
- **Convention**:
  - Input: SPAD 7=current TCB addr
  - Scratch: SP 0-4,7; DPX 0-3; DA
- **Side Effects**:
  - Modifies IMASK register
  - Calls PSMNGR for ISR residency
- **Cross-references**: Calls RMVCLK, PSMNGR, RTCINT, INTEXT

**INTEXT** (Interrupt Exit)
- **Convention**:
  - Output: SPAD 0=SYSPTR-1
  - Scratch: SP 0-1
- **Side Effects**:
  - Dispatches to EXTASK (tasks) or MNREST (ISRs)
- **Cross-references**: Called by all interrupt handlers

**RTCINT** (RTC Handler)
- **Convention**:
  - Output: DPX(1)=TCB addr, SPAD 0=queue status
  - Scratch: SP 0-4; DPX 0-3
- **Side Effects**:
  - Processes clock timeouts
  - Calls DELETE/RESUME for task state changes
- **Cross-references**: Calls EMPTY, DELETE, RESUME

### 4. Architectural Insights
1. **Two-Level Context Management**:
   - Minimal context (MNREST) for fast switches
   - Full context (MXSAVE/MXREST) for task preemption
   - TCB stores DPX/SPAD state across switches

2. **Overlay System**:
   - Segments managed via 8-word overlay tables
   - PS residency tracked with "should-be/currently-res" bits
   - MOVER handles 2:1 MD:PS word compression

3. **Interrupt Hierarchy**:
   - Nested interrupts with IMASK priority levels
   - Common INTEXT exit decouples handler from return path
   - RTC handled separately from device I/O

4. **Queue Architecture**:
   - Ready queues with priority insertion
   - Clock queues for timeouts
   - "Morgue" queue for terminated tasks

### 5. Design Observations
1. **Performance Optimization**:
   - Fast path: 48 cycles for same-task resumption
   - Slow path: 377-389 cycles for full context switch
   - Inline queue operations to minimize memory access

2. **Memory Efficiency**:
   - Overlay system optimizes limited PS space
   - Fixed-offset TCB layouts enable fast access
   - MD holds state, PS holds code

3. **1979 Idioms**:
   - Heavy use of register arithmetic (INCMA, ADD R0,R1)
   - Manual queue management vs. abstract data structures
   - Explicit timing analysis in comments
   - Global state via MD offsets (CURTSK, NEWTSK, etc.)

4. **Resilience**:
   - Spurious interrupt detection in IO handler
   - Queue integrity checks in INSERT/DELETE
   - Exception termination via "morgue" queue

The code reveals a sophisticated but resource-constrained RTOS designed for interrupt-driven embedded systems, with particular attention to minimizing context-switch overhead and maximizing PS memory utilization.

</details>



---

## Group: `kernel_supervisor`

**Mini-100 supervisor body**

Files: `MINI.S`

### DeepSeek final

(adv 80s, 19693c)

## Critique of Peer Analysis

The peer analysis is generally accurate but has several significant shortcomings:

1. **Incorrect subsystem identification**: The analysis claims this is "Mini-100 supervisor" but the code itself states "SUPER-100 VERSION: MARCH 79, S. CAMLEY" and "MINI-100 VERSION: AUG 79, S. CAMLEY" - this is actually the **Super-100** supervisor that was adapted for Mini-100. The code handles both.

2. **Missing architectural details**: The analysis fails to note critical AP-120B architectural features revealed by the code:
   - The `APSTAT2` register encoding of interrupt type (bits 0-2)
   - The `IMASK` register for I/O interrupt prioritization
   - The `SRS` (Subroutine Return Stack) depth of 16 entries
   - The `TMRAM` (Table Memory RAM) addressing scheme

3. **Incorrect overlay entry format**: The analysis states "8-word entries" but the code shows the overlay map entry format explicitly in PSMNGR comments: Word 1=seg#, Word 2=MD addr, Word 3=PS addr, Word 4=length, Word 5=task ID, Word 6=residency, Word 7=partition ptr, Word 8=partition count.

4. **Missing critical routines**: The analysis doesn't document `OVLAY2` properly - it's a marker routine that sets the "should-be-resident" bit without calling PSMNGR, unlike `OVLAY1`.

5. **Incorrect timing analysis**: The analysis states "15 cycles for single-resident segment" but the code comments say "15 CYCLES FOR 1-SEGMENT TASK (OR ISR) WHICH IS ALREADY RESIDENT" - this is the total PSMNGR overhead, not per-segment.

6. **Missing architectural insight**: The analysis doesn't note the critical fact that `MOVER` runs in **user mode with interrupts enabled** - this is a key design decision for responsiveness during code loading.

7. **Incorrect device count**: The analysis says "15 total" devices but the CONFIG table has entries for DEV1-DEV15, with some IOP devices sharing the same ISR entry (DEV8/9 share ISRMAP+(W*8), DEV10/11 share ISRMAP+(W*8), etc.).

---

# Final Reference Analysis: MINI.S - Super-100/Mini-100 Supervisor

## 1. Subsystem Overview

MINI.S constitutes the **core supervisor** for the FPS-100 operating in Super-100 or Mini-100 mode. It provides:

- **Interrupt dispatch and context management**: Save/restore of full machine state (43 words minimum) across all interrupt types
- **Overlay management**: Dynamic loading of code segments from Main Data (MD) memory into Program Source (PS) memory
- **I/O interrupt handling**: Priority-based dispatch to device-specific Interrupt Service Routines (ISRs)
- **System call (TRAP) handling**: Dispatch to supervisor call (SVC) routines
- **Fatal error handling**: System halt on unrecoverable conditions

The supervisor operates in **two privilege modes**:
- **Supervisor mode** (SMA, interrupts off): For critical state manipulation
- **User mode** (UMA, interrupts on): For overlay code movement and ISR execution

The code reveals a **stack-based context management** system using a dedicated save area (`SSAREA`) managed by `SYSPTR`, with bounds checking to prevent corruption.

---

## 2. Per-File Purpose

### SYSCOM (System Common)
- **$TITLE**: `SYSCOM`
- **$ENTRY**: None (data section)
- **$EXT**: None
- **Purpose**: Defines global supervisor data structures in `/DOT/` common block and static data
- **Data manipulated**:
  - `RDYQUE(1-2)`: Task ready queue pointers (2 words)
  - `SYSAVE` = `SSAREA`: Base address of system save area
  - `SYSPTR` = `SSAREA`: Current save area pointer (initialized to base)
  - `SYSTOP` = `SSAREA+SYSIZE-1`: Top of save area
  - `LOGITS`: Counter for spurious trap interrupts
  - `LOGIOD`: Counter for spurious I/O interrupts
- **Architectural state**: MD locations for supervisor global variables

### CONFIG (Device Configuration)
- **$TITLE**: `CONFIG`
- **$ENTRY**: None (data section)
- **$EXT**: None
- **Purpose**: Static I/O device configuration table mapping interrupt priority to ISRs
- **Entry format** (5 words per device):
  - Word 1: Priority mask (to mask lower-priority devices)
  - Word 2: Bit mask (this device's IMASK bit)
  - Word 3: Pointer to ISR entry in overlay map (`ISRMAP+offset`)
  - Word 4: Device order number (EXP) / Physical device address (LMAN)
  - Word 5: Save area for old IMASK
- **Devices mapped** (15 entries, some sharing ISRs):
  - DEV1-DEV4: Unspecified high-priority devices (priority 040000-004000)
  - DEV5: Real-time clock (device address 372 octal)
  - DEV6: Host DMA (priority 001000)
  - DEV7: Host non-DMA interrupt (priority 000400)
  - DEV8-DEV13: IOP16/IOP38 DMA and non-DMA interrupts (share ISRMAP+(W*8))
  - DEV14-DEV15: GPIOP devices (share ISRMAP+(W*13))
- **Architectural state**: MD configuration table, `IMASK` register bits

### SAVRST (Save/Restore)
- **$TITLE**: `SAVRST`
- **$ENTRY**: `MNSAVE`, `MNREST`
- **$EXT**: `TRAP`, `FATAL`, `FPE`, `IO`, `INTEXT`
- **Purpose**: Full machine state save/restore on interrupt
- **Timing**: 119-127 cycles save, 93 cycles restore (minimum state)
- **Saved state** (43 words in order):
  1. MD FIFO(1)
  2. MD FIFO(2)
  3. MD FIFO(3)
  4. (Hole - currently unused)
  5. DPX write buffer
  6. APSTAT1
  7-10. DPX(0-3)
  11. Device Address (DA)
  12. SPD
  13. SP(0)
  14. SPFN
  15-21. SP(1-7)
  22. APSTAT2
  23. TMA
  24. TMREG
  25. FFT status bits
  26. User MA
  27. APSTAT3
  28-43. SRS(15-0)
- **Key operations**:
  - Swaps MD FIFO(1) and FIFO(3) for correct restore order
  - Validates SYSPTR bounds against SSAREA
  - Dispatches to appropriate handler based on APSTAT2 bits 0-2
- **Cross-reference**: Called from `INTEXT` (restore), dispatches to `TRAP`/`FATAL`/`FPE`/`IO`

### OVHNDL (Overlay Handler)
- **$TITLE**: `OVHNDL`
- **$ENTRY**: `OVHNDL` (host entry), `APOVLD` (APFTN entry), `OVLD` (APAL entry)
- **$EXT**: `OVLAY1`, `OVLAYM`, `WATLIT`
- **Purpose**: Load overlays from MD to PS memory
- **Entry points**:
  - `OVHNDL`: Host-initiated via APRUN - loads accumulated overlays from DTABLK, then JSRT to user subroutine
  - `APOVLD`: APFTN call - fetches overlay ID from DTABLK, calls OVLD
  - `OVLD`: APAL call - S-Pad 10 = overlay ID, calls OVLAY1
- **Data**: Uses `/DOT/` common block (DTABLK):
  - `ENTLOC` = DTABLK+0: PS entry point of called subroutine
  - `OVCNT` = DTABLK+1: Number of overlays to load
  - `OVIDS` = DTABLK+2: Array of overlay ID numbers
- **Scratch**: SP 0-7, DPX 0-3, TMA
- **Cross-reference**: Calls `OVLAYM` (via TRAP), `WATLIT`, returns to host via HALT

### OVLAY (Overlay SVCs)
- **$TITLE**: `OVLAY`
- **$ENTRY**: `OVLAYM` (multiple overlays), `OVLAY1` (single/last), `OVLAY2` (marker)
- **$EXT**: `INTEXT`, `PSMNGR`
- **Purpose**: Mark overlays as "should-be-resident" and make them resident
- **Overlay map entry format** (8 words, WIDTH=8):
  - Word 1: Overlay segment number
  - Word 2: MD address
  - Word 3: PS address
  - Word 4: Length (in PS words)
  - Word 5: Task ID or TCB address
  - Word 6: Residency (EXP=currently resident, LMAN=should be resident)
  - Word 7: Pointer to first PS partition table entry
  - Word 8: Number of PS partition entries
- **Key routines**:
  - `OVLAYM`: Processes multiple overlays from host request, calls `OVLAY2` for each except last, then `OVLAY1` for last
  - `OVLAY1`: Sets entry flag=1, marks segment should-be-resident, calls `PSMNGR`, then `INTEXT`
  - `OVLAY2`: Sets entry flag=0, marks segment should-be-resident, returns (for use in loop)
- **Parameters**: SP7=task save area, DPX(0)=segment number
- **Scratch**: SP 0-7, DPX 0-3
- **Cross-reference**: Calls `PSMNGR`, `INTEXT`

### PSMNGR (PS Manager)
- **$TITLE**: `PSMNGR`
- **$ENTRY**: `PSMNGR`
- **$EXT**: `MOVER`
- **Purpose**: Ensure all "should-be-resident" overlays are actually resident in PS
- **Parameters**: DPX(3)=addr of first overlay table entry, DPX(2)=number of consecutive entries
- **Process**:
  1. Check each segment: if should-be-resident == is-resident, continue
  2. If mismatch found: locate PS partitions for this segment
  3. Mark old segments in those partitions as non-resident
  4. Mark new segment as resident
  5. Call `MOVER` to transfer code from MD to PS
  6. Restart check from beginning (in case interrupt changed PS contents)
- **Timing**: 15 cycles for 1-segment task already resident; 9+6*N for N-segment resident task
- **Scratch**: SP 0-6 (preserves SP7=TCB), DPX 0-3
- **Cross-reference**: Calls `MOVER`

### MOVER (Code Mover)
- **$TITLE**: `MOVER`
- **$ENTRY**: `MOVER`
- **Purpose**: Move code from MD to PS (2 MD words = 1 PS word)
- **Parameters**: DPX(0)=PS address, DPX(1)=MD address, DPX(2)=number of PS words
- **Mode switch**: Supervisor→User mode, SMA→UMA, interrupts enabled during transfer
- **Loop structure** (3 instructions, 5 cycles per PS word):
  ```
  LOOP: INCMA;         LPSRT; DB=MD    -- get 1st half, store 2nd half of previous
        INCMA;         INCTMA;         -- get 2nd half, increment PS pointer
        DEC CTR;       LPSLT; DB=MD    -- decrement counter, store 1st half
        BGT LOOP       -----           -- branch if more words
  ```
- **Early termination**: Drops out one cycle early to avoid overflow on last word
- **Scratch**: SP 0, DPX 0-2, TMA (preserves DPX(3))
- **Cross-reference**: Called from `PSMNGR`

### TRAP (Trap Handler)
- **$TITLE**: `TRAP`
- **$ENTRY**: `TRAP`
- **$EXT**: `INTEXT`
- **Purpose**: Handle TRAP interrupt (system call)
- **Process**:
  1. Load TMA (SVC address) and DPX 0-3 from TCB save area
  2. Execute `JSRT` to SVC via TMA
  3. Store DPX 0-3, SP 0, SPFN back to TCB
  4. Jump to `INTEXT`
- **Assumptions**: User's last instruction was `TRAP; DB=@XXX; LDTMA` where XXX is SVC address
- **Timing**: 20 cycles plus SVC
- **Clobbers**: User's DPX 0-3, SP 0
- **Cross-reference**: Calls `INTEXT`

### IO (I/O Interrupt Handler)
- **$TITLE**: `IO`
- **$ENTRY**: `IO`
- **$EXT**: `PSMNGR`, `INTEXT`
- **Purpose**: Dispatch I/O interrupts to appropriate ISR
- **Process**:
  1. Read interrupting device number from `IOINTA`
  2. Index into CONFIG table (5-word entries, W=5)
  3. Mask out current and lower-priority devices via IMASK
  4. Save old IMASK in device table entry
  5. Call `PSMNGR` to ensure ISR is resident
  6. Switch to user mode, call ISR via `JSRT`
  7. On return: reconstruct IMASK = (current AND NOT pri_mask) OR returned_bit_mask OR old_IMASK
- **ISR parameters**: SP0=bit mask, SP1=device order number, SP2=physical device address
- **Spurious interrupt handling**: Increments `LOGIOD` counter
- **Timing**: 56 cycles plus ISR (41 in IO + 15 in PSMNGR if resident)
- **Scratch**: SP 0-4,7, DPX 0-3, DA
- **Cross-reference**: Calls `PSMNGR`, `INTEXT`

### INTEXT (Interrupt Exit)
- **$TITLE**: `INTEXT`
- **$ENTRY**: `INTEXT`
- **$EXT**: `MNREST`
- **Purpose**: Common interrupt exit path
- **Process**: Sets SP0 and SMA to SYSPTR-1, jumps to `MNREST`
- **Timing**: 6 cycles
- **Cross-reference**: Called from `TRAP`, `IO`, `OVLAY1`, `FATAL`, `FPE`

### FATAL (Fatal/FPE Handler)
- **$TITLE**: `FATAL`
- **$ENTRY**: `FATAL`, `FPE`
- **Purpose**: Handle fatal exceptions and floating-point exceptions
- **Actions**:
  - `FPE`: Halt with DB=76 (octal)
  - `FATAL`: Halt with DB=1
- **Note**: Comment indicates these are placeholder handlers; users may customize

---

## 3. Key Routines - Detailed Documentation

### MNSAVE (SAVRST)
- **Calling convention**: Entered via hardware interrupt vector
  - SP7 = addr of task's save area (set by interrupt hardware)
  - APSTAT2 bits 0-2 encode interrupt type
- **Architectural side effects**:
  - **Reads**: MD FIFO(1-3), DPX write buffer, APSTAT1, DPX(0-3), DA, SPD, SP(0-7), SPFN, APSTAT2, TMA, TMREG, FFT status, MA, APSTAT3, SRS(15-0)
  - **Writes**: 43 words to MD save area starting at SYSPTR
  - **Modifies**: SYSPTR (incremented by 43), SMA (set to SYSPTR-1)
  - **APSTAT2**: Cleared after reading (to allow TM references without FFT mode interference)
- **Cross-references**: Dispatches to `TRAP` (trap), `FATAL` (fatal), `FPE` (FPE), `IO` (I/O), or increments `LOGITS` (false interrupt)

### MNREST (SAVRST)
- **Calling convention**: Entered from `INTEXT`
  - SP0 = SYSPTR-1 (pre-set by INTEXT)
  - SMA = SYSPTR-1
- **Architectural side effects**:
  - **Reads**: 43 words from MD save area
  - **Writes**: MD FIFO(1-3), DPX write buffer, APSTAT1, DPX(0-3), DA, SPD, SP(0-7), SPFN, APSTAT2, TMA, TMREG, FFT status, MA, APSTAT3, SRS(15-0)
  - **Modifies**: SYSPTR (decremented by 43), SRS (restored via SETEXT)
  - **Final instruction**: `EXINT; RETURN` - restores previous mode and interrupt state, returns to interrupted code
- **Critical ordering**: Restore sequence is reverse of save; SRS restore uses `SETEXT` to push onto stack

### PSMNGR
- **Calling convention**: 
  - DPX(3) = addr of first overlay table entry (or RES word within it)
  - DPX(2) = number of consecutive entries
  - Supervisor mode, SMA, interrupts off
- **Architectural side effects**:
  - **Reads**: Overlay map entries (8 words each), PS partition table entries
  - **Writes**: Residency bits in overlay map (EXP and LMAN bits)
  - **Calls**: `MOVER` (which switches to user mode)
  - **Returns**: DPX(3) pointing to RES word of first entry
- **Scratch**: SP 0-6, DPX 0-3 (preserves SP7=TCB)
- **Cross-references**: Called from `IO` and `OVLAY1`

### MOVER
- **Calling convention**:
  - DPX(0) = PS address
  - DPX(1) = MD address
  - DPX(2) = number of PS words
- **Architectural side effects**:
  - **Mode switch**: `SELMA` (user MA), `CLRMOD` (user mode), `ION` (interrupts on)
  - **Mode restore**: `ENTINT` (supervisor mode, SMA, interrupts on)
  - **Memory**: Reads MD, writes PS via `LPSRT`/`LPSLT`
  - **TMA**: Used as PS pointer, incremented via `INCTMA`
- **Scratch**: SP 0, DPX 0-2, TMA (preserves DPX(3))
- **Timing**: 5 cycles per PS word moved

### IO Handler
- **Calling convention**: Entered from MNSAVE dispatch
  - SP7 = addr of task's save area
  - Supervisor mode, SMA, interrupts off
- **Architectural side effects**:
  - **Reads**: `IOINTA` (device number), CONFIG table, IMASK register
  - **Writes**: IMASK register (via OUT), device table entry word 5 (old IMASK)
  - **Calls**: `PSMNGR` (may modify overlay residency), ISR (via JSRT in user mode)
  - **IMASK reconstruction**: (current AND NOT pri_mask) OR returned_bit_mask OR old_IMASK
- **Scratch**: SP 0-4,7, DPX 0-3, DA

---

## 4. Architectural Insights

### Interrupt Architecture
The code reveals the AP-120B's interrupt system in detail:

1. **APSTAT2 encoding** (bits 0-2):
   - Bit 0 (APMO): Previous mode (0=user, 1=supervisor)
   - Bit 1 (PINTU): Previous universal interrupt enable/disable
   - Bit 2 (PMAS): Previous MA/SMA select
   - These bits are used by `MNSAVE` to dispatch to the correct handler

2. **Interrupt types** (tested in order by MNSAVE):
   - Trap (bit 0 set): Software TRAP instruction
   - Fatal (bit 1 set): Hardware fatal error
   - FPE (bit 2 set): Floating-point exception
   - I/O (bit 3 set): I/O device interrupt
   - False interrupt: None of the above

3. **I/O interrupt priority**: The CONFIG table maps IMASK bits to device priorities. The IO handler masks out the current device and all lower-priority devices by ORing the priority mask with the current IMASK.

4. **Spurious interrupt handling**: Both `LOGITS` (trap) and `LOGIOD` (I/O) counters track false interrupts, suggesting these were not uncommon in the hardware.

### Memory Management

1. **Save area management**: `SSAREA` is a fixed-size circular buffer managed by `SYSPTR`. The code validates that `SYSPTR` stays within bounds (`SYSAVE` to `SYSTOP`), halting with error codes 78 (save overflow) or 79 (restore underflow).

2. **Overlay system**: The overlay map is a per-task structure in MD with 8-word entries. The residency word (word 6) uses:
   - EXP bit: Currently resident in PS
   - LMAN bit: Should be resident (requested but not yet loaded)

3. **PS partition management**: Each overlay segment can span multiple PS partitions (word 7-8 of overlay entry). The PS manager handles fragmentation by tracking which segments occupy which partitions.

### Context Switching Details

1. **SRS save/restore**: The 16-level subroutine return stack is saved to MD using `REXIT`/`SETEX` instructions. The restore uses `SETEXT` to push values back onto the stack, with careful loop control to avoid SRS overflow.

2. **MD FIFO management**: The save sequence swaps FIFO(1) and FIFO(3) so that during restore, FIFO(1) is output first and FIFO(3) last - matching the hardware FIFO behavior.

3. **FFT mode handling**: APSTAT2 is cleared early in save to prevent FFT mode from corrupting TM references. FFT status bits are saved separately and restored via `LDAPS` before the final TM restore.

### Host-AP Communication

1. **APRUN protocol**: The host places overlay IDs in MD(DTABLK), then calls `OVHNDL` which loads all requested overlays and JSRTs to the user subroutine.

2. **APOVLD protocol**: AP-resident code can request overlays via the TRAP instruction, which vectors through `OVLAY1`/`OVLAY2` to the PS manager.

---

## 5. Design Observations

### Performance Optimizations

1. **Tight loop coding**: The `MOVER` loop achieves 5 cycles per PS word by carefully pipelining MD reads and PS writes across two instruction columns.

2. **Minimum state save**: Only 43 words are saved/restored, with the comment noting this is the "minimum state" - suggesting a tradeoff between context switch speed and functionality.

3. **Early termination patterns**: Both `MOVER` and the SRS restore loop use early termination (dropping out one iteration early) to avoid overflow conditions.

4. **Dual-mode operation**: Overlay loading runs in user mode with interrupts enabled, allowing the system to remain responsive during I/O-bound code transfers.

### Coding Idioms

1. **Two-column instruction format**: The code uses APAL's dual-column format extensively, with the left column typically handling memory operations and the right column handling register operations.

2. **STATMA/INCMA sequences**: These are used for atomic MA manipulation, with `STATMA` storing the current MA value and `INCMA` incrementing it.

3. **LDSPI/DB= patterns**: Constants are loaded via `LDSPI` with `DB=` immediate values, showing the S-Pad load instruction format.

4. **MOV 0,0 / MOV 1,1 patterns**: These no-op instructions are used for timing synchronization, ensuring pipeline hazards are resolved.

### Error Handling

1. **Bounds checking**: Both save and restore validate SYSPTR against SSAREA bounds, halting with unique error codes (78 for save overflow, 79 for restore underflow).

2. **Spurious interrupt tracking**: Counters `LOGITS` and `LOGIOD` accumulate false interrupt counts, suggesting diagnostic use.

3. **Fatal halt codes**: Different halt codes distinguish error types:
   - 1: Fatal exception
   - 76: Floating-point exception
   - 77: Overlay segment not found
   - 78: System save area overflow
   - 79: System save area underflow

### Memory Layout

1. **SSAREA**: Fixed-size system save area with stack-like management via SYSPTR
2. **CONFIG**: Static device configuration table in common block
3. **ISRMAP**: Overlay map for ISR entries (120 words)
4. **DTABLK**: 33-word communication area for host-AP parameter passing

### Interrupt Design Philosophy

1. **Common exit path**: All interrupt handlers converge on `INTEXT`, which sets up the restore and jumps to `MNREST`. This ensures consistent state restoration.

2. **Priority-based I/O**: The IMASK register is manipulated to prevent nested interrupts from same or lower-priority devices, while allowing higher-priority interrupts.

3. **ISR residency guarantee**: The IO handler calls `PSMNGR` before dispatching to the ISR, ensuring the ISR code is resident in PS memory even if it was previously swapped out.

### GLM final

(adv 128s, 9611c)

### Analysis of MINI.S — Mini-100 Supervisor Body

---

#### 1. **Subsystem Overview**
MINI.S implements the core supervisor kernel for the Mini-100/Super-100 mode of the FPS-100 array processor. It provides:
- **Interrupt handling** for all vectorable interrupts (trap, fatal, FPE, I/O, and spurious interrupts)
- **Context switching** with a 119-127 cycle state save and 93 cycle restore
- **Overlay management** for loading code segments into PS memory
- **PS memory management** including residency tracking and partition allocation
- **I/O device configuration** with priority-based interrupt masking
- **Task scheduling** via a system save area stack

This kernel transforms the FPS-100 from a host-driven processor (AP-120B mode) into an autonomous system capable of multi-tasking with interrupt-driven I/O.

---

#### 2. **Per-File Purpose**

##### **SYSCOM**  
- **$TITLE**: SYSCOM  
- **$ENTRY**: None (data initialization)  
- **$EXT**: None  
- **Purpose**: Initializes system common data areas, including the ready queue pointers (`RDYQUE`), system save area boundaries (`SYSAVE`, `SYSPTR`, `SYSTOP`), and interrupt counters (`LOGITS`, `LOGIOD`).  
- **AP state manipulated**: MD locations for system variables (DTABLK, SSAREA).  

##### **CONFIG**  
- **$TITLE**: CONFIG  
- **$ENTRY**: None (data initialization)  
- **$EXT**: None  
- **Purpose**: Defines the 15-device I/O configuration table (DEV1–DEV15) and ISR overlay map (ISRMAP). Each device entry is 5 words: priority mask, bit mask, ISR overlay pointer, device order/address, and IMASK save area.  
- **AP state manipulated**: MD locations for device configuration tables and ISR pointers.  

##### **SAVRST**  
- **$TITLE**: SAVRST  
- **$ENTRY**: `MNSAVE`, `MNREST`  
- **$EXT**: `TRAP`, `FATAL`, `FPE`, `IO`, `INTEXT`  
- **Purpose**: Implements hardware-context save/restore. `MNSAVE` saves 43 items (MD FIFO, DPX, S-Pads, SRS, APSTAT registers) and dispatches to interrupt handlers. `MNREST` restores state and returns to the interrupted context.  
- **AP state manipulated**: All major state (MD FIFO, DPX 0–3, S-Pads 0–7, SPFN, SPD, DA, APSTAT1–3, TMA, TMREG, SRS 0–15).  

##### **OVHNDL**  
- **$TITLE**: OVHNDL  
- **$ENTRY**: `OVHNDL`, `APOVLD`, `OVLD`  
- **$EXT**: `OVLAY1`, `OVLAYM`, `WATLIT`  
- **Purpose**: `OVHNDL` is the host entry point for overlay loading during APRUN. `APOVLD` (APFTN) and `OVLD` (APAL) load single overlays by ID.  
- **AP state manipulated**: TMA (trap address), DPX(0) (segment ID), PS memory.  

##### **OVLAY**  
- **$TITLE**: OVLAY  
- **$ENTRY**: `OVLAYM`, `OVLAY1`, `OVLAY2`  
- **$EXT**: `INTEXT`, `PSMNGR`  
- **Purpose**: `OVLAYM` marks multiple overlay segments as "should-be-resident" and triggers PSMNGR. `OVLAY1`/`OVLAY2` handle single overlays, marking residency via the overlay map.  
- **AP state manipulated**: DPX 0–3, S-Pads 0–7, overlay map residency bits.  

##### **PSMNGR**  
- **$TITLE**: PSMNGR  
- **$ENTRY**: `PSMNGR`  
- **$EXT**: `MOVER`  
- **Purpose**: Manages PS residency: marks segments as "should-be-resident," finds PS partitions, evicts old segments, and loads new segments via MOVER. Re-checks segments after loading (handles interruptions).  
- **AP state manipulated**: DPX 0–3, S-Pads 0–6, overlay map entries, PS partition tables.  

##### **MOVER**  
- **$TITLE**: MOVER  
- **$ENTRY**: `MOVER`  
- **$EXT**: None  
- **Purpose**: Transfers code from MD to PS (2 MD words = 1 PS word). Temporarily switches to user mode with interrupts enabled.  
- **AP state manipulated**: DPX 0–2, SP 0, TMA, PS memory, MA, mode bits.  

##### **TRAP**  
- **$TITLE**: TRAP  
- **$ENTRY**: `TRAP`  
- **$EXT**: `INTEXT`  
- **Purpose**: Handles SVC calls by loading TMA/DPX 0–3 from the task save area, executing JSRT to the SVC, and saving registers back to the save area.  
- **AP state manipulated**: DPX 0–3, SP 0–1, SP 7, TMA, save area.  

##### **IO**  
- **$TITLE**: IO  
- **$ENTRY**: `IO`  
- **$EXT**: `PSMNGR`, `INTEXT`  
- **Purpose**: Handles I/O interrupts: identifies the device via IOINTA, masks interrupts, ensures ISR residency via PSMNGR, calls the ISR, and adjusts IMASK on return.  
- **AP state manipulated**: DPX 0–3, SP 0–4, SP 7, DA, IMASK, device tables.  

##### **INTEXT**  
- **$TITLE**: INTEXT  
- **$ENTRY**: `INTEXT`  
- **$EXT**: `MNREST`  
- **Purpose**: Common interrupt exit routine. Sets SMA/SP 0 to SYSPTR-1 and jumps to MNREST.  
- **AP state manipulated**: SP 0, SMA.  

##### **FATAL**  
- **$TITLE**: FATAL  
- **$ENTRY**: `FATAL`, `FPE`  
- **$EXT**: None  
- **Purpose**: Terminates tasks on fatal/FPE interrupts. `FATAL` halts with code 1; `FPE` halts with code 76.  
- **AP state manipulated**: None (halts).  

---

#### 3. **Key Routines**

##### **MNSAVE (Minimum State Save)**  
- **Calling convention**: Entered via hardware interrupt. SP 7 = save area. APSTAT2 bits 0–2 hold pre-interrupt state (mode, INTU, MA/SMA).  
- **Side effects**:  
  - Reads: MD FIFO, DPX write buffer, APSTAT1, DPX(0–3), DA, SPD, SPFN, SP(0–7), TMA, TMREG, FFT status, MA, APSTAT3, SRS(0–15).  
  - Writes: System save area (43 words), updates SYSPTR = SMA+1.  
- **Cross-references**: Jumps to `TRAP`, `FATAL`, `FPE`, `IO`, or `INTEXT`.  

##### **MNREST (Minimum State Restore)**  
- **Calling convention**: Entered with SMA/SP 0 = SYSPTR-1 (pre-fetched first item).  
- **Side effects**:  
  - Reads: System save area.  
  - Writes: SRS(0–15), APSTAT3, MA, FFT status, TMA, TMREG, APSTAT2, SP(7–0), SPFN, SPD, DA, DPX(3–0), APSTAT1, DPX write buffer, MD FIFO.  
- **Cross-references**: Called by `INTEXT`.  

##### **OVLAYM (Multiple Overlay SVC)**  
- **Calling convention**: SP 7 = save area. DTABLK holds overlay count and ID array.  
- **Side effects**:  
  - Reads: DTABLK, overlay map, RDYQUE.  
  - Writes: Overlay map residency bits (WRTEXP).  
- **Cross-references**: Calls `OVLAY2` in loop, then `OVLAY1`.  

##### **PSMNGR (PS Memory Manager)**  
- **Calling convention**: DPX(3) = overlay table entry, DPX(2) = entry count.  
- **Side effects**:  
  - Reads: Overlay map entries, PS partition tables.  
  - Writes: Residency bits, PS partition tables.  
- **Cross-references**: Calls `MOVER`.  
- **Timing**: 15 cycles if resident; 9 + 6N cycles for N-segment checks.  

##### **MOVER (Code Mover)**  
- **Calling convention**: DPX(0) = PS addr, DPX(1) = MD addr, DPX(2) = PS word count.  
- **Side effects**:  
  - Reads: MD (2 words per PS word).  
  - Writes: PS memory.  
- **Mode switch**: User mode with interrupts enabled during transfer.  
- **Timing**: 5 cycles per PS word.  

##### **IO (I/O Interrupt Handler)**  
- **Calling convention**: SP 7 = save area. Supervisor mode, SMA, interrupts off.  
- **Side effects**:  
  - Reads: IOINTA, IMASK, device tables.  
  - Writes: IMASK, device table IMASK save area.  
- **Timing**: 56 cycles + ISR (41 in IO + 15 in PSMNGR).  

---

#### 4. **Architectural Insights**

1. **Hardware-Assisted Interrupt Capture**  
   - APSTAT2 bits 0–2 automatically capture pre-interrupt state (APMO, PINTU, PMAS) – a Mini-100/Super-100 hardware feature.

2. **43-Item Context State**  
   - Save sequence captures hardware state (MD FIFO, DPX write buffer, SRS 0–15, APSTAT registers) and critical software state (SPFN, SPD, DA). This exceeds typical CPU context saves.

3. **SRS Stack Access**  
   - SRS(0–15) are saved via `REXIT/SETEX` (popping the stack), revealing a non-standard way to access the subroutine return stack.

4. **Overlay Management Architecture**  
   - 8-word overlay map entries track: segment number, MD/PS addresses, length, task ID, residency flags, and PS partition pointers. Two residency bits (EXP/LM) enable complex residency tracking.

5. **I/O Priority Handling**  
   - 15 devices mapped to IMASK bits (bit 14 = highest priority). Handler masks the current device AND lower-priority devices, then restores IMASK based on ISR return value.

6. **System Save Area as Stack**  
   - SYSPTR dynamically manages save area storage (SYSAVE ≤ SMA ≤ SYSTOP), with overflow/underflow checks preventing corruption.

---

#### 5. **Design Observations**

1. **Performance Optimizations**  
   - **Pre-fetching**: MNREST pre-reads the first restore item to hide memory latency.  
   - **Two-column execution**: Indented loops (e.g., MNSAVE, PSMNGR) exploit the AP's dual-column instruction format for 2 ops/cycle.  
   - **Early loop exits**: MOVER and SRS restore loops drop out early to avoid overflow.  
   - **FIFO reordering**: MNSAVE swaps MD FIFO(1)/FIFO(3) to ensure correct restore order.

2. **Error Handling**  
   - Halts with specific codes: 78 (save overflow), 79 (restore underflow), 77 (overlay not found), 76 (FPE), 1 (fatal).  
   - SYSAVE ≤ SMA ≤ SYSTOP enforced in MNSAVE/MNREST.

3. **System Integration**  
   - Common exit path (`INTEXT`) ensures consistent state restoration.  
   - TCB-based save areas with fixed offsets for TMA/DPX/S-Pads.  
   - Overlay maps linked to PS partitions for memory management.

4. **Mode Switching Pattern**  
   - Uses `CLRMOD` (user mode), `SELMA` (user MA), `ION` (interrupts), `ENTINT` (supervisor mode).

5. **Evolution Timeline**  
   - Developed from March 78 (G.J. Throop) to August 79 (S. Camley), reflecting refinement for Mini-100 capabilities.  
   - Code shows hand-optimization for a 1979 embedded RTOS, prioritizing predictability over density.

This supervisor reveals a sophisticated interrupt-driven architecture with careful state management, optimized for real-time embedded operation. The overlay system and I/O priority handling distinguish it as a high-performance 1979 design.

<details><summary>Cooperative drafts</summary>

#### DS coop

# Analysis of MINI.S — Mini-100 Supervisor Body

## 1. Subsystem Overview

MINI.S is the **core supervisor kernel** for the FPS-100 operating in Mini-100/Super-100 mode. It implements the complete interrupt handling infrastructure, context switching, overlay management, and system initialization for the AP-side operating system. This is the code that transforms the FPS-100 from a host-driven array processor (AP-120B mode) into a self-supervising processor capable of running multiple tasks with interrupt-driven I/O.

The subsystem provides:
- **Interrupt dispatch** (trap, fatal, floating-point exception, I/O)
- **Full machine state save/restore** (minimum 119-127 cycles save, 93 cycles restore)
- **Overlay management** (loading code segments from MD to PS)
- **PS memory management** (partition tracking, residency tracking)
- **I/O device configuration and interrupt handling**
- **System save area management** (stack-based context storage)

## 2. Per-File Purpose

### SYSCOM (System Common Initializations)
- **$TITLE**: SYSCOM
- **Public entries**: None (data only)
- **Externals**: None
- **Purpose**: Defines the system common data block `/DOT/` (33 words), the ready queue pointer (`RDYQUE`), system save area boundaries (`SYSAVE`, `SYSPTR`, `SYSTOP`), and counters for spurious interrupts (`LOGITS`, `LOGIOD`).
- **AP state manipulated**: MD locations for system variables

### CONFIG (I/O Device Configuration Table)
- **$TITLE**: CONFIG
- **Public entries**: None (data only)
- **Externals**: None
- **Purpose**: Defines 15 device entries in `/CONFIG/` common block, each 5 words describing an I/O device: priority mask, bit mask, pointer to overlay map entry, device order number/physical address, and IMASK save area. Also defines `/ISRMAP/` dummy array (120 words) for ISR overlay map entries.
- **AP state manipulated**: MD locations for device configuration

### SAVRST (Save/Restore Sequence)
- **$TITLE**: SAVRST
- **Public entries**: `MNSAVE` (minimum state save), `MNREST` (minimum state restore)
- **Externals**: `TRAP`, `FATAL`, `FPE`, `IO`, `INTEXT`
- **Purpose**: Implements the complete interrupt context save and restore. Saves 43 items of machine state (MD FIFO, DPX registers, S-Pads, SRS stack, APSTAT registers, TMA, TMREG, FFT status, etc.) to the system save area. After save, dispatches to appropriate handler based on interrupt type. Restore reverses the process.
- **AP state manipulated**: All major architectural state (MD FIFO, DPX, S-Pads 0-7, SPFN, SPD, DA, APSTAT1-3, TMA, TMREG, SRS 0-15, MA, FFT status)

### OVHNDL (Overlay Handler)
- **$TITLE**: OVHNDL
- **Public entries**: `OVHNDL` (host entry), `APOVLD` (APFTN entry), `OVLD` (APAL entry)
- **Externals**: `OVLAY1`, `OVLAYM`, `WATLIT`
- **Purpose**: Handles overlay loading requests. `OVHNDL` is called by host during APRUN to load accumulated overlays and transfer control. `APOVLD`/`OVLD` are called by user tasks to load a single overlay segment by ID number.
- **AP state manipulated**: TMA (for trap to overlay SVC), DPX(0) (overlay segment number), PS memory (via overlay loading)

### OVLAY (Overlay Services)
- **$TITLE**: OVLAY
- **Public entries**: `OVLAYM` (multiple overlay SVC), `OVLAY1` (single/last overlay SVC), `OVLAY2` (intermediate overlay SVC)
- **Externals**: `INTEXT`, `PSMNGR`
- **Purpose**: Implements the overlay service routines called via trap. `OVLAYM` handles multiple overlays from host request by marking each as "should-be-resident" then calling PS manager. `OVLAY1`/`OVLAY2` handle single overlay requests, searching the task's overlay map for the segment ID, marking it, and either returning (OVLAY2) or calling PS manager (OVLAY1).
- **AP state manipulated**: DPX 0-3, S-Pads 0-7, overlay map entries in MD (residency bits), TMA

### PSMNGR (PS Manager)
- **$TITLE**: PSMNGR
- **Public entries**: `PSMNGR`
- **Externals**: `MOVER`
- **Purpose**: Manages PS memory by checking which overlay segments should be resident vs. currently resident. For segments that need loading, it finds their PS partitions, marks old segments as non-resident, marks new segments as resident, and calls MOVER to transfer code from MD to PS. Re-checks all segments after loading (in case of interruption).
- **AP state manipulated**: DPX 0-3, S-Pads 0-6, overlay map entries (residency bits), PS partition table entries, SYSPTR

### MOVER (Code Mover)
- **$TITLE**: MOVER
- **Public entries**: `MOVER`
- **Externals**: None
- **Purpose**: Transfers code from MD to PS (2 MD words = 1 PS word). Temporarily switches to user mode with interrupts enabled for the transfer, then returns to supervisor mode. Uses a 3-instruction, 5-cycle loop.
- **AP state manipulated**: DPX 0-2, SP 0, TMA, PS memory, MA, mode bits, interrupt enable

### TRAP (Trap Handler)
- **$TITLE**: TRAP
- **Public entries**: `TRAP`
- **Externals**: `INTEXT`
- **Purpose**: Handles trap interrupts (SVC calls). Loads TMA and DPX 0-3 from the task's TCB save area, performs JSRT to the SVC address, then stores DPX 0-3, SP 0, and SPFN back to the save area.
- **AP state manipulated**: DPX 0-3, SP 0, SP 1, SP 7, TMA, task save area in MD

### IO (I/O Interrupt Handler)
- **$TITLE**: IO
- **Public entries**: `IO`
- **Externals**: `PSMNGR`, `INTEXT`
- **Purpose**: Handles I/O interrupts by identifying the interrupting device from the I/O interrupt acknowledge register, masking out further interrupts from that device and lower-priority devices, ensuring the ISR is resident via PSMNGR, switching to user mode, JSRT to the ISR, then re-adjusting the IMASK register on return.
- **AP state manipulated**: DPX 0-3, SP 0-4, SP 7, DA, IMASK register, device configuration table entries, ISR overlay map entries

### INTEXT (Interrupt Exit)
- **$TITLE**: INTEXT
- **Public entries**: `INTEXT`
- **Externals**: `MNREST`
- **Purpose**: Common interrupt exit routine. Sets SMA and SP 0 to SYSPTR-1, then jumps to MNREST to restore the interrupted task's state.
- **AP state manipulated**: SP 0, SMA

### FATAL (Fatal/Exception Interrupt Handler)
- **$TITLE**: FATAL
- **Public entries**: `FATAL`, `FPE`
- **Externals**: None
- **Purpose**: Handles fatal and floating-point exception interrupts. Currently both result in abnormal termination (HALT with error codes 1 for fatal, 76 for FPE).
- **AP state manipulated**: None (halts)

## 3. Key Routines

### MNSAVE (Minimum State Save)
- **Calling convention**: Entered via hardware interrupt vector. Mode = supervisor, memory select = SMA, universal interrupts inhibited. APSTAT2 bits 0-2 contain pre-interrupt mode/INTU/MA-SMA state.
- **AP side effects**:
  - **Reads**: MD FIFO (3 reads), DPX write buffer, APSTAT1, DPX(0-3), DA, SPD, SPFN, SP(0-7), TMA, TMREG, FFT status, MA, APSTAT3, SRS(0-15)
  - **Writes**: System save area (43 words starting at SYSPTR), SYSPTR updated to SMA+1
  - **Registers modified**: All S-Pads, DPX, TMA, MA, SMA
- **Cross-references**: Calls `TRAP`, `FATAL`, `FPE`, `IO`, `INTEXT` via jump table

### MNREST (Minimum State Restore)
- **Calling convention**: Entered with SMA and SP 0 set to SYSPTR-1 (pre-fetched first restore item). Mode = supervisor, SMA, interrupts off.
- **AP side effects**:
  - **Reads**: System save area (43 words)
  - **Writes**: SRS(0-15), APSTAT3, MA, FFT status, TMA, TMREG, APSTAT2, SP(7-0), SPFN, SPD, DA, DPX(3-0), APSTAT1, DPX write buffer, MD FIFO
  - **Registers modified**: All restored state, SYSPTR decremented by MNSIZE
- **Cross-references**: Called from `INTEXT`

### OVHNDL (Host Entry Point)
- **Calling convention**: Host places in MD: DTABLK+0 = PS entry point, DTABLK+1 = number of overlays, DTABLK+2+ = overlay ID numbers. Called during APRUN.
- **AP side effects**:
  - **Reads**: DTABLK entries
  - **Writes**: PS memory (via overlay loading), TMA
  - **Registers modified**: TMA, DPX
- **Cross-references**: Calls `OVLAYM` (via trap), `WATLIT`, halts with `DBLLIT=0` on completion

### OVLD/APOVLD (Overlay Load Entry)
- **Calling convention**: APAL: S-Pad 10 = overlay ID, JSR OVLD. APFTN: CALL APOVLD(OVID).
- **AP side effects**:
  - **Reads**: DTABLK (APOVLD), S-Pad 10 (OVLD)
  - **Writes**: DPX(0) with segment number, TMA with trap address
  - **Registers modified**: DPX(0), TMA
- **Cross-references**: Calls `OVLAY1` (via trap)

### OVLAYM (Multiple Overlay SVC)
- **Calling convention**: SP 7 = task save area address. Parameters in DTABLK: OVCNT = count, OVIDS = array of segment numbers.
- **AP side effects**:
  - **Reads**: DTABLK entries, overlay map entries
  - **Writes**: Overlay map residency bits (should-be-resident)
  - **Registers modified**: SP 5-7, DPX 0
- **Cross-references**: Calls `OVLAY2` in loop, then `OVLAY1` for last segment

### OVLAY1/OVLAY2 (Single Overlay SVC)
- **Calling convention**: SP 7 = task save area, DPX(0) = segment number. OVLAY1 sets entry flag=1, OVLAY2 sets entry flag=0.
- **AP side effects**:
  - **Reads**: Task's overlay map (8-word entries), RDYQUE for TCB pointer
  - **Writes**: Overlay map residency word (sets should-be-resident bit via WRTEXP)
  - **Registers modified**: SP 0-7, DPX 0-3
- **Cross-references**: Calls `PSMNGR`, then `INTEXT` (OVLAY1 only)

### PSMNGR (PS Memory Manager)
- **Calling convention**: DPX(3) = address of first overlay table entry, DPX(2) = number of consecutive entries. Supervisor mode, SMA, interrupts off.
- **AP side effects**:
  - **Reads**: Overlay map entries (residency words), PS partition table entries
  - **Writes**: Residency words (marking old segments non-resident, new segments resident), PS partition table entries
  - **Registers modified**: SP 0-6, DPX 0-3
  - **Timing**: 15 cycles if already resident, 9+6N cycles for N-segment check
- **Cross-references**: Calls `MOVER`

### MOVER (Code Mover)
- **Calling convention**: DPX(0) = PS address, DPX(1) = MD address, DPX(2) = number of PS words.
- **AP side effects**:
  - **Reads**: MD (2 words per PS word)
  - **Writes**: PS memory
  - **Registers modified**: SP 0, DPX 0-2, TMA
  - **Mode**: Temporarily switches to user mode with interrupts enabled
  - **Timing**: 5 cycles per PS word
- **Cross-references**: Called from `PSMNGR`

### TRAP (Trap Handler)
- **Calling convention**: SP 7 = task save area address. User's last instruction was `TRAP; DB=@XXX; LDTMA`.
- **AP side effects**:
  - **Reads**: Task save area (TMA, DPX 0-3)
  - **Writes**: Task save area (DPX 0-3, SP 0, SPFN after SVC returns)
  - **Registers modified**: DPX 0-3, SP 0, SP 1, TMA
  - **Timing**: 20 cycles plus SVC
- **Cross-references**: Calls SVC via JSRT, then `INTEXT`

### IO (I/O Interrupt Handler)
- **Calling convention**: SP 7 = task save area address. Supervisor mode, SMA, interrupts off.
- **AP side effects**:
  - **Reads**: IOINTA register, IMASK register, device configuration table, overlay map entries
  - **Writes**: IMASK register (masks out current and lower priority devices), device table IMASK save area
  - **Registers modified**: SP 0-4, SP 7, DPX 0-3, DA
  - **Timing**: 56 cycles plus ISR (41 in IO + 15 in PSMNGR if resident)
- **Cross-references**: Calls `PSMNGR`, then `INTEXT`

### INTEXT (Interrupt Exit)
- **Calling convention**: Supervisor mode, SMA, interrupts off.
- **AP side effects**:
  - **Reads**: SYSPTR
  - **Writes**: SP 0 = SYSPTR-1, SMA = SYSPTR-1
  - **Timing**: 6 cycles
- **Cross-references**: Jumps to `MNREST`

## 4. Architectural Insights

### Context Save/Restore Architecture
The code reveals a sophisticated interrupt handling mechanism not documented in the basic AP-120B manual:

1. **Hardware state capture**: On interrupt, the hardware automatically saves mode bits (APMO), previous interrupt enable (PINTU), and previous MA/SMA select (PMAS) into APSTAT2 bits 0-2. This is a hardware feature of the Mini-100/Super-100 variant.

2. **43-item minimum state**: The save sequence captures 43 distinct items including MD FIFO (3 levels), DPX write buffer, DPX(0-3), DA, SPD, SP(0-7), SPFN, APSTAT1-3, TMA, TMREG, FFT status bits, MA, and SRS(0-15). This is far more than a typical context save on other architectures.

3. **FIFO swap trick**: Lines 22-28 of MNSAVE swap FIFO(1) and FIFO(3) so that during restore, FIFO(1) comes out first and FIFO(3) last. This is a clever workaround for the FIFO ordering.

4. **SRS manipulation**: The code reads the subroutine return stack (SRS) by using REXIT/SETEX instructions, which is a non-standard way to access the hardware stack. It saves SRS(15) through SRS(0) by repeatedly popping the stack.

5. **System save area as stack**: The supervisor uses a stack-based save area (SYSPTR points to the next free location). The save area boundaries (SYSAVE to SYSTOP) are checked to prevent overflow.

### Interrupt Dispatch Mechanism
The interrupt dispatch in MNSAVE uses a clever bit-testing sequence:
- Tests APSTAT2 bits to determine interrupt type
- Jumps to TRAP, FATAL, FPE, or IO based on which bit is set
- Falls through to INTEXT for false interrupts (counted in LOGITS)

### Overlay Management Architecture
The overlay system reveals a complex memory management scheme:

1. **8-word overlay map entries**: Each segment has: segment number, MD address, PS address, length, task ID, residency word (EXP=resident, LM=should-be-resident), PS partition table pointer, partition count.

2. **Two-level residency tracking**: Each segment has a "should-be-resident" bit and a "currently-resident" bit. The PS manager compares these to determine if loading is needed.

3. **PS partition table**: Segments can span multiple PS partitions. Each partition entry tracks which segment currently occupies it.

4. **Re-check after load**: After loading a segment, PSMNGR re-checks all segments because an interrupt during MOVER could have changed PS contents.

### I/O Interrupt Handling
The I/O system reveals:

1. **15 device priority levels**: Mapped to IMASK bits 0-14, with device 1 (bit 14) highest priority.

2. **Device configuration table**: 5-word entries with priority mask, bit mask, overlay map pointer, device order/physical address, and IMASK save area.

3. **IMASK manipulation**: The handler masks out the current device AND all lower priority devices, then restores the old IMASK OR'd with the returned bit mask from the ISR.

4. **ISR calling convention**: ISRs receive SP0=bit mask, SP1=device order number, SP2=physical device address. They return with the bit mask in SP0 to indicate whether to enable/disable further interrupts from that device.

### Supervisor/User Mode Switching
The code shows a pattern for mode switching:
- `CLRMOD` sets user mode
- `SELMA` sets user MA
- `ION` enables interrupts
- `ENTINT` returns to supervisor mode with interrupts on and SMA

## 5. Design Observations

### Performance Tricks

1. **Pre-fetching**: MNREST pre-fetches the first restore item by setting SMA and SP 0 before entering the restore sequence. The comment notes "THIS PRE-FETCHES THE FIRST ELEMENT OF THE SUBROUTINE RETURN STACK."

2. **Two-column instruction format**: The code consistently uses the AP's dual-column instruction format to execute two operations per cycle. The indentation in the source code visually indicates the two columns.

3. **Loop optimization**: MOVER uses a 3-instruction, 5-cycle loop that processes one PS word per iteration. The comment explains the critical timing assumption about INCMA and LPSRT executing in the same cycle.

4. **Early loop exit**: Both MOVER and the SRS restore loop drop out one iteration early to avoid overflow conditions.

5. **Register reuse**: The code carefully manages register allocation, noting which S-Pads and DPX registers are scratch vs. preserved across calls.

### Coding Patterns

1. **System save area as stack pointer**: SYSPTR is used as a stack pointer for context saves, with bounds checking against SYSAVE and SYSTOP.

2. **Error halts with codes**: System errors halt with specific codes (78 for save area overflow, 79 for restore underflow, 77 for overlay not found, 76 for FPE, 1 for fatal).

3. **Common exit path**: All interrupt handlers converge on INTEXT, which sets up for MNREST. This ensures consistent state restoration.

4. **TCB-based parameter passing**: Task save areas are referenced via SP 7, with fixed offsets for TMA, DPX registers, and S-Pads.

5. **Overlay map as linked structure**: The overlay map entries are linked to PS partition table entries, creating a two-level mapping from segment IDs to physical PS locations.

### Historical Notes
The header comments document the evolution:
- Original: March 78, G.J. Throop
- Test version: February 79, G.J. Throop
- Super-100 version: March 79, S. Camley
- Mini-100 version: August 79, S. Camley

This shows the code evolved from the AP-120B through Super-100 to Mini-100 over about 18 months.

#### GLM coop

### 1. Subsystem Overview  
The `kernel_supervisor` (MINI.S) forms the core of the Mini-100 supervisor, responsible for:  
- **Interrupt handling**: Trap, I/O, fatal, and FPE interrupts  
- **Memory management**: Overlay loading into PS memory, code moving from MD to PS  
- **System state management**: Context save/restore during interrupts  
- **Device configuration**: I/O interrupt mapping and prioritization  
- **Multi-tasking support**: Ready queue management, TCB interactions  
- **Host-AP communication**: Overlay requests via APRUN/APOVLD  

This code runs in **supervisor mode** with interrupts masked during critical sections, switching to user mode for overlay management. The supervisor uses a **stack-based save area** (SSAREA) for context switches and relies on the **overlay map** in TCBs for dynamic code loading.

---

### 2. Per-File Purpose  
*(Note: MINI.S combines multiple subsystems under one file; each $TITLE defines a distinct component.)*  

#### **SYSCOM** (System Common)  
- **$TITLE**: `SYSCOM`  
- **$ENTRY**: None (common data section)  
- **$EXT**: None  
- **Purpose**: Defines global supervisor data structures.  
- **Data manipulated**:  
  - `RDYQUE(1-2)`: Task ready queues  
  - `SYSAVE/SSAREA`: System save area boundaries  
  - `SYSPTR`: Current save area pointer  
  - `LOGITS/LOGIOD`: False interrupt counters  
- **Architectural state**: MD (data store), S-Pad (register offsets)  

#### **CONFIG** (Device Configuration)  
- **$TITLE**: `CONFIG`  
- **$ENTRY**: None  
- **$EXT**: None  
- **Purpose**: Static I/O device interrupt mapping table.  
- **Entry format** (5 words/device):  
  - Priority mask, bit mask, overlay table pointer, device order/address, IMASK save slot  
- **Devices mapped**: Host DMA, real-time clock, IOP16/IOP38, GPIOP (15 total).  
- **Architectural state**: MD (configuration storage), DPX (temporary storage)  

#### **SAVRST** (Save/Restore)  
- **$TITLE**: `SAVRST`  
- **$ENTRY**: `MNSAVE`, `MNREST`  
- **$EXT**: `TRAP`, `FATAL`, `FPE`, `IO`, `INTEXT`  
- **Purpose**: Minimal interrupt context save/restore (119-127 save/93 restore cycles).  
- **Saved state**:  
  - MD FIFO(1-3), DPX buffer, APSTAT1, DPX(DPA-DPA+3), DA, SPD, SP(0-7), APSTAT2, TMA, TMREG, SRS(15-0).  
- **Key operations**:  
  - Swaps MD FIFO(1/3) to restore correct order.  
  - Validates SYSPTR bounds; halts if corrupted.  
- **Cross-reference**: `MNSAVE` dispatches to `TRAP`/`IO`/etc. after save.  

#### **OVHNDL** (Overlay Handler)  
- **$TITLE**: `OVHNDL`  
- **$ENTRY**: `OVHNDL` (host), `APOVLD` (APFTN), `OVLD` (APAL)  
- **$EXT**: `OVLAY1`, `OVLAYM`, `WATLIT`  
- **Purpose**: Loads overlays from MD to PS.  
- **Entry types**:  
  - `OVHNDL`: Host-initiated (uses DTABLK for overlay list).  
  - `APOVLD`/`OVLD`: AP-initiated (single overlay load).  
- **Data**: Uses `/DOT/` (DTABLK) for overlay metadata.  
- **Scratch**: SP 0-7, DPX 0-3 (clobbers TMA).  

#### **OVLAY** (Overlay SVCs)  
- **$TITLE**: `OVLAY`  
- **$ENTRY**: `OVLAYM` (multiple), `OVLAY1` (single), `OVLAY2` (marker)  
- **$EXT**: `INTEXT`, `PSMNGR`  
- **Purpose**: Manages overlay residency in task overlay maps.  
- **Overlay entry format**: 8 words (seg ID, MD addr, PS addr, length, TCB ptr, residency, partition ptr/ct).  
- **Key routines**:  
  - `OVLAYM`: Marks overlays as "should-be-resident" from host request.  
  - `OVLAY1`: Ensures overlay residency via `PSMNGR`.  
- **Residency bit**: Uses LMAN=1 in overlay map's RES word.  

#### **PSMNGR** (PS Manager)  
- **$TITLE**: `PSMNGR`  
- **$ENTRY**: `PSMNGR`  
- **$EXT**: `MOVER`  
- **Purpose**: Makes "should-be-resident" overlays actually resident.  
- **Process**:  
  1. Checks residency vs. should-be-resident status.  
  2. If not resident: finds PS partitions, marks old overlays non-resident, calls `MOVER`.  
- **Performance**: 15 cycles for single-resident segment; 9+6*N cycles for N segments.  

#### **MOVER** (Code Mover)  
- **$TITLE**: `MOVER`  
- **$ENTRY**: `MOVER`  
- **Purpose**: Copies data from MD to PS (2 MD words = 1 PS word).  
- **Mode switch**: Runs in user mode with interrupts enabled.  
- **Loop**: 5 cycles/PS word (INCMA + LPSRT/LPSLT pattern).  

#### **TRAP** (Trap Handler)  
- **$TITLE**: `TRAP`  
- **$ENTRY**: `TRAP`  
- **$EXT**: `INTEXT`  
- **Purpose**: Processes trap interrupts.  
- **Process**:  
  - Loads TMA and DPX 0-3 from TCB.  
  - Executes JSRT to SVC.  
  - Stores DPX 0-3, SP 0, SPFN back to TCB.  
- **Clobbers**: User DPX 0-3, SP 0.  

#### **IO** (I/O Interrupt Handler)  
- **$TITLE**: `IO`  
- **$ENTRY**: `IO`  
- **$EXT**: `PSMNGR`, `INTEXT`  
- **Purpose**: Dispatches I/O interrupts to ISRs.  
- **Process**:  
  1. Masks interrupting device/lower-priority devices.  
  2. Ensures ISR residency via `PSMNGR`.  
  3. Calls ISR with parameters (SP0: bit mask, SP1: device order, SP2: address).  
  4. Updates IMASK from ISR return value.  
- **Device table**: Uses 5-word entries from CONFIG.  

#### **INTEXT** (Interrupt Exit)  
- **$TITLE**: `INTEXT`  
- **$ENTRY**: `INTEXT`  
- **$EXT**: `MNREST`  
- **Purpose**: Common interrupt exit path.  
- **Process**: Sets SP0/SMA = SYSPTR-1, jumps to `MNREST`.  

#### **FATAL** (Fatal/FPE Handler)  
- **$TITLE**: `FATAL`  
- **$ENTRY**: `FATAL`, `FPE`  
- **Purpose**: Halts system on fatal exceptions.  
- **Actions**:  
  - `FATAL`: Halt with DB=1.  
  - `FPE`: Halt with DB=76.  

---

### 3. Key Routines  

#### `MNSAVE` (SAVRST)  
- **Calling convention**: Interrupt context (SP7=TCB).  
- **Architectural side effects**:  
  - Saves 26-43 words to MD (FIFO, DPX, S-Pads, SRS).  
  - Sets SYSPTR to SMA+1 (validated against SSAREA).  
- **Cross-reference**: Dispatches to `TRAP`/`IO`/etc. via jump table.  

#### `PSMNGR`  
- **Calling convention**: DPX(3)=overlay map addr, DPX(2)=segment count.  
- **Side effects**: Updates residency bits, calls `MOVER`.  
- **Scratch**: SP 0-6 (preserves SP7=TCB).  

#### `MOVER`  
- **Calling convention**: DPX(0)=PS addr, DPX(1)=MD addr, DPX(2)=word count.  
- **Side effects**: Switches to user mode/MA, enables interrupts.  
- **Loop**: 5 cycles/word (tightly pipelined INCMA + LPSRT/LPSLT).  

#### `IO`  
- **Calling convention**: SP7=TCB.  
- **Side effects**: Updates IMASK, calls `PSMNGR` and ISR.  
- **Device handling**: Uses CONFIG table for ISR lookup.  

---

### 4. Architectural Insights  
1. **Interrupt Handling**:  
   - **APSTAT2** bits encode interrupt type (trap, fatal, FPE, I/O).  
   - **False interrupts**: Counted in `LOGITS`/`LOGIOD` (overflow protection).  
   - **Priority masking**: CONFIG table bits combined with IMASK for interrupt isolation.  

2. **Overlay Management**:  
   - **Overlay map**: Per-task TCB with 8-word entries (seg ID, addresses, residency flags).  
   - **Lazy loading**: Segments marked "should-be-resident" (LMAN=1) via `OVLAY2`, then materialized by `PSMNGR`.  
   - **Code paging**: `MOVER` handles 2:1 MD:PS expansion in user mode.  

3. **Context Switching**:  
   - **SRS (Stack) save**: Pushed to MD during `MNSAVE`, restored in `MNREST`.  
   - **SYSPTR**: Stack-like pointer managing SSAREA; validated pre-access.  

4. **Host-AP Communication**:  
   - **APRUN**: Host-triggered overlay loading via `OVHNDL`.  
   - **APOVLD**: AP-initiated overlay request from MD (DTABLK).  

---

### 5. Design Observations  
1. **Performance Optimization**:  
   - **Tight loops**: `MOVER` uses 5-cycle/word pipelining; `MNSAVE` minimizes state (43 words).  
   - **Dual-mode operation**: Overlay management in user mode allows interrupts during code moves.  

2. **Memory Layout**:  
   - **SSAREA**: Linear save area managed by `SYSPTR` (stack-like).  
   - **Overlay partitions**: Embedded in overlay map (word 7: ptr, word 8: count).  

3. **Idioms**:  
   - **Register pressure**: SP 0-7 used for scratch; DPX 0-3 for parameters.  
   - **Atomic operations**: `STATMA`/`INCMA` sequences for MA manipulation.  
   - **Early termination**: `MOVER` loop drops out early to avoid overflow.  

4. **Error Handling**:  
   - **Bounds checking**: `MNSAVE`/`MNREST` validate SSAREA access.  
   - **Halt paths**: Fatal errors hard-coded (DB=1/76).  

5. **Interrupt Design**:  
   - **Common exit**: `INTEXT` centralizes restore.  
   - **Device table**: Static CONFIG mapping interrupts to overlay ISRs.  

This analysis reveals a highly optimized, interrupt-driven supervisor with careful attention to performance and memory efficiency, leveraging hardware features like SRS and DMA overlays for context switching.

</details>



---

## Group: `kernel_syssvc`

**System-service routines (AP-side syscall handlers)**

Files: `SYSSVC.S`

### DeepSeek final

(adv 84s, 20868c)

## Critique of Peer Analysis

The peer analysis (GLM) provides a reasonable high-level overview but has several significant shortcomings:

1. **Incorrect file grouping**: Treats each `$TITLE` section as a separate file, when SYSSVC.S is a single file containing multiple titled sections. The `$TITLE` directive in APAL merely labels code sections within a single source file.

2. **Missing architectural details**: Fails to explain critical AP-120B microarchitectural features revealed by the code, such as:
   - The FIFO swap trick in MNSAVE (lines swapping FIFO(1) and FIFO(3))
   - How the floating-point pipeline state is reconstructed from stored instructions
   - The SRA (Subroutine Return Address) stack manipulation for SRS save/restore

3. **Inaccurate calling conventions**: States "no params" for MNSAVE, but the entry assumes specific AP state (Supervisor mode, SMA selected, interrupts inhibited) as documented in the source comments.

4. **Missing critical details**: The `$INSERT COMSYS` and `$INSERT SYSDEF` directives are mentioned but their contents (defining TCB offsets, queue structures, etc.) are not analyzed.

5. **Overlooks important idioms**: The two-column loop structure, the use of `STATMA` as a NOP/pipeline synchronizer, and the `DPX<SPFN`/`MOV 0,0` pattern for register-to-register moves are not explained.

---

## Final Reference Analysis

### 1. Subsystem Overview

SYSSVC.S implements the **system service call (SVC) handlers** for the AP-side supervisor (Super-100/Mini-100 mode). This single source file (1724 lines) contains the following subsystems:

- **Context Save/Restore** (`$TITLE SAVRST`): The interrupt entry/exit sequence that saves/restores all AP architectural state. This is the most timing-critical code in the system (123-148 cycles for save, 92-177 for restore).

- **Inter-Task Communication** (`$TITLE WAIT`, `ANSWER`, `SEND`, `RECEIV`): A message-passing IPC system using exchange queues. Tasks block on exchanges waiting for messages; senders wake waiting tasks.

- **Task Scheduling** (`$TITLE RESUME`, `RUNPRI`): Priority-based ready queue management. Tasks are inserted into the ready queue by priority; priorities can be changed dynamically.

- **Floating-Point Exception Control** (`$TITLE SETFPE`): Per-task enable/disable of floating-point exception interrupts.

- **Overlay Management** (`$TITLE OVHNDL`, `OVLAY`): Dynamic loading of overlay segments from MD (Main Data memory) into PS (Program Source memory). Supports both host-initiated and task-initiated overlay loads.

### 2. Per-Section Purpose

| $TITLE | Public Entries | Externals | Purpose | AP State Manipulated |
|--------|---------------|-----------|---------|---------------------|
| **SAVRST** | `MNSAVE`, `MNREST`, `MXSAVE`, `MXREST` | `TRAP`, `FATAL`, `FPE`, `IO`, `INTEXT` | Interrupt context save/restore. Saves minimum state (128 words) on interrupt, then optionally saves full context (256 words total). | MD FIFO, DPX/DPY write buffers, S-Pads 0-7, SPFN, SPD, DA, APSTAT1/2/3, TMA, TMREG, FFT status, MA, SRS stack (16 levels), floating-point adder/multiplier pipeline, flags 0-3, DPA, DPX/DPY data pads (28 each) |
| **WAIT** | `WAIT`, `TWAIT`, `WAITA`, `TWAITA` | `DELETE`, `DEQ`, `EMPTY`, `RECEIV`, `INSERT`, `RESUME`, `ADDCLK` | Task blocks on exchange waiting for message/answer. Supports timed waits with timeout. | TCB status (ready bit cleared), exchange queue, clock queue, ready queue |
| **ANSWER** | `ANSWER`, `MSGANS` | `SENDA` | Sends answer to last received message. Validates message is unlinked and sets answer bit. | TCB last-message field, message type field, exchange queue |
| **SEND** | `SEND`, `SENDA` | `INSERT`, `DEQ`, `EMPTY`, `RECEIV` | Sends message to exchange. If tasks waiting, dequeues task and delivers message; otherwise queues message. | Exchange type bits (MSGBIT/TSKBIT), message priority, TCB answer exchange field |
| **RECEIV** | `RECEIV` | `RESUME`, `RMVCLK` | Task receives message. Updates TCB with message address/type, reinserts task into ready queue, removes from clock queue. | TCB DPX0/SPFUNC/SP0 save areas, TCB last-message field, TCB run priority (if slave), ready queue, clock queue |
| **RESUME** | `RESUME` | `PRIQ` | Inserts task into ready queue by priority. Sets task's ready bit. | TCB status (ready bit), ready queue |
| **RUNPRI** | `RUNPRI`, `SETPRI` | `DELETE`, `RESUME` | Changes task's run priority. If task is in ready queue, removes and reinserts at new priority. | TCB run priority, TCB default priority, ready queue |
| **SETFPE** | `SETFPE` | (none) | Enables/disables floating-point exception interrupt for current task. | APSTAT2 (bit 10), TCB APSTAT2 save area |
| **OVHNDL** | `OVHNDL`, `APOVLD`, `OVLD` | `OVLAY1`, `OVLAYM` | Loads overlays into PS memory. Host entry loads multiple overlays then jumps to user code; task entries load single overlay. | PS memory (via LDTMA/JSRT), overlay map in MD |
| **OVLAY** | `OVLAYM`, `OVLAY1`, `OVLAY2` | `PSMNGR`, `EXTASK` | Marks overlay segments as should-be-resident in TCB overlay map, then calls PS manager to make them resident. | TCB overlay map entries (RES word), segment count |

### 3. Key Routines

#### 3.1 MNSAVE (Minimum State Save)

**Entry conditions** (from source comments):
- Mode = Supervisor
- Memory Select = SMA
- Universal interrupts inhibited
- APSTAT2 bits 0-2 contain pre-interrupt state (APMO, PINTU, PMAS)

**Calling convention**: No explicit parameters. Entered via hardware interrupt vector. Returns by jumping to one of: `TRAP`, `FATAL`, `FPE`, `IO`, `INTEXT`.

**Architectural side effects**:
- **MD FIFO**: Saves FIFO(1), FIFO(2), FIFO(3) to memory (lines 1-3)
- **DPX write buffer**: Saved via `RDPI`/`WDPI` sequence (line 5)
- **APSTAT1**: Saved (line 6)
- **DPX(0-3)**: Saved (lines 7-10)
- **DA, SPD, S-Pads 0-7, SPFN**: Saved (lines 11-21)
- **FIFO swap trick**: Lines after "THE FOLLOWING CODE SWAPS FIFO(1) AND FIFO(3)" - reads SMA, computes offsets to swap FIFO(1) and FIFO(3) in memory so restore order is correct
- **APSTAT2**: Saved via I/O device 377 (line 22)
- **TMA, TMREG**: Saved (lines 23-24)
- **FFT status bits**: Saved (line 25)
- **MA (user)**: Saved via `ROMA` (line 26)
- **APSTAT3**: Saved via I/O device 376 (line 27)
- **SRS stack**: 16 entries saved using `REXIT`/`SETEX` loop (lines 28-43). SRA set to 15, then loop reads stack top and stores to memory

**SYSPTR management** (after minimum save):
- Compares SMA against SYSAVE/SYSTOP bounds
- If SYSAVE < SMA <= SYSTOP: SYSPTR = SMA + 1
- If SMA = SYSAVE or SYSTOP < SMA <= SYSTOP+MNSIZE: HALT (fatal error)
- Otherwise: SYSPTR = SYSAVE

**Interrupt dispatch**:
- Reads CURTSK from MD
- Tests APSTAT2 bits via `MOVR` shifts:
  - Bit 0: TRAP interrupt → `JMP TRAP`
  - Bit 1: FATAL interrupt → `JMP FATAL`
  - Bit 2: FPE interrupt → `JMP FPE`
  - Bit 3: IO interrupt → `JMP IO`
  - None: False interrupt → increment counter, `JMP INTEXT`

**Timing**: 123-130 cycles (minimum), 145-148 (with MXSAVE)

#### 3.2 MXSAVE (Maximum State Save)

**Entry conditions**: SMA pointing to beginning of max save area in TCB

**Calling convention**: Called after MNSAVE dispatch. No explicit parameters.

**Architectural side effects**:
- **S-Pads 8-15**: Saved using `RSPFN`/`LDSPD` loop (lines 44-51)
- **DPY write buffer**: Saved (line 52)
- **DPY(0-3)**: Saved with `INCDPA` (lines 53-56)
- **Data pads (DPX/DPY 28 each)**: Saved in opposite order from restore. Loop uses `INCDPA` on store, `DECDPA` on restore (lines 57-112)
- **DPA**: Saved (line 113)
- **Floating-point adder state**: Complex save sequence (lines 114-118):
  - Pushes A2 via `FPA2`, saves old FA
  - Pushes A1 via `FPA1`, checks for floating-point error (`BFPE FAERR`)
  - If no error: saves A2, A1, zero for A1, old FA
  - If error: detects overflow/underflow, saves appropriate constants
  - Reconstructs FADD instruction from APSTAT3 bits 10-15, stores as 118th word
- **Floating-point multiplier state**: Save sequence (lines 119-124):
  - Saves FM0-FM2 pipeline stages
  - Each stage: saves FM value, then pushes pipeline with `FMUL`
  - Checks for FPE at each stage; if error, saves multiplier constant to regenerate error on restore
- **Flags 0-3**: Tested via `BFL0`-`BFL3`, saved as 1 or 0 (lines 125-128)

**Cross-references**: Called from interrupt dispatch in MNSAVE. Restore counterpart is MXREST.

#### 3.3 MXREST (Maximum State Restore)

**Entry conditions**: SMA pointing to end of max save area (pre-fetched last word)

**Calling convention**: Called before MNREST. No explicit parameters.

**Architectural side effects** (reverse of MXSAVE):
- **Flags 0-3**: Restored using `BDBZ`/`SFLx` sequence (reverse order: flag3 first)
- **Multiplier**: Restored by executing `FMUL` with saved operands (FM01/FM02 generate FM0, etc.)
- **Adder**: Complex restore (lines after RSTFA):
  - Loads saved FADD instruction into `FAOLD` location via `LPSL FAOLD`
  - Normalizes/unnormalizes old FA as needed
  - Executes reconstructed instruction at `FAOLD: FADD DPX,MD` to restore exact adder state
- **Data pads**: Restored using `DECDPA` loop (opposite direction from save)
- **DPY(0-3) and DPYW**: Restored
- **S-Pads 8-15**: Restored using `LDSPD`/`DEC 2` loop

#### 3.4 MNREST (Minimum State Restore)

**Entry conditions**: SMA and SP0 set to end of min save area (pre-fetched SRS(0))

**Calling convention**: Called after MXREST. Returns via `EXINT`/`RETURN` to restored task.

**Architectural side effects**:
- **SYSPTR management**: If SYSAVE < SYSPTR <= SYSTOP+1, SYSPTR = SYSPTR-MNSIZE; otherwise SYSPTR = SYSAVE
- **SRS stack**: Restored using `SETEXT`/`JSR LDSTK` loop. Note: loop drops out one early to avoid SRS overflow interrupt
- **APSTAT3**: Restored via I/O device 376, SRA set to 15
- **User MA**: Restored via `LDOMA`
- **FFT status bits**: Restored via APSTAT2 (device 377)
- **TMA**: Restored via TMRAM (device 5) with temporary value 177776
- **S-Pads 0-7, SPFN, SPD, DA**: Restored in reverse order
- **DPX(0-3)**: Restored
- **APSTATUS**: Restored via `LDAPS`
- **DPX write buffer**: Restored via `WDPI`
- **Final state**: `EXINT` restores previous interrupt state (mode, INTU, MA/SMA), then `RETURN` exits

**Timing**: 92-96 cycles (minimum), 168-177 (with MXREST)

#### 3.5 WAIT/TWAIT/WAITA/TWAITA

**Calling convention**:
- `WAIT`: DPX(1) = exchange address. Cannot be called via JSR (must trap)
- `TWAIT`: DPX(0) = time limit, DPX(1) = exchange address. Can JSR only with time limit=0
- `WAITA`/`TWAITA`: Same as above but waiting for answer (uses ANSKEY from TCB)
- Return: DPX(0) = message address, SP0/SPFN = message type

**S-Pad usage** (defined at top):
```
FLAG = 0    EXCH = 1    EXTYPE = 4
TCB = 5     MSG = 6
```

**Procedure**:
1. Get TCB address from CURTSK
2. For WAITA/TWAITA: get answer exchange from TCB.ANSKEY
3. Call `DELETE` to remove task from ready queue
4. Clear task's ready bit in TCB status
5. Check exchange type for MSGBIT
6. If message waiting: `DEQ` message, `EMPTY` check (clear exchange type if empty), `RECEIV` message
7. If no message:
   - If not timed wait: `INSERT` task into exchange queue
   - If timed wait with time limit=0: `RESUME` task, return TIMOUT message with TIMBIT type
   - If timed wait with non-zero limit: `ADDCLK` to clock queue, `INSERT` into exchange queue

**Cross-references**: Calls `DELETE`, `DEQ`, `EMPTY`, `RECEIV`, `INSERT`, `RESUME`, `ADDCLK` (all external)

#### 3.6 SEND/SENDA

**Calling convention**:
- `SEND`: DPX(0) = message address, DPX(1) = exchange address
- `SENDA`: Same parameters (alternate entry for answers)
- Return: No explicit return value (error codes in SP0 on failure)

**S-Pad usage**:
```
PRI = 0    EXCH = 1    TCB = 2    MSG = 3    EXTYPE = 4
```

**Procedure**:
1. Validate message is unlinked (RLINK(MSG) == MSG)
2. Set message's busy bit
3. Copy current task's priority into message priority
4. Copy message's answer exchange into TCB.ANSKEY
5. Check exchange's TSKBIT:
   - If no tasks waiting: set MSGBIT, `INSERT` message into exchange queue
   - If tasks waiting: `DEQ` a task, `EMPTY` check (clear exchange type if empty), `RECEIV` message to task

**Error handling**: Returns ERRBSY if message linked elsewhere

#### 3.7 RECEIV

**Calling convention**:
- Input: DPX(0) = message address, DPX(1) = TCB address
- Output: DPX(0) = message address, SP0/SPFN = message type

**S-Pad usage**:
```
TCB = 6    MSG = 2    PRI = 3    MTYPE = 4    SAVEM = 5
```

**Procedure**:
1. Get TCB status, check SLVBIT (slave bit)
2. If slave: copy message priority to TCB run priority
3. Get message type
4. If regular message (type=0): store message address in TCB.LSTMSG
5. If answer message: clear message's busy bit
6. Store message address in TCB.DPX0 save area
7. Store message type in TCB.SPFUNC and TCB.SP0 save areas
8. Call `RESUME` to add task to ready queue
9. Call `RMVCLK` to remove task from clock queue (if present)

#### 3.8 OVHNDL/APOVLD/OVLD

**Calling convention**:
- `OVHNDL`: Called by host via APRUN. Uses DTABLK in MD: DTABLK(0)=PS entry point, DTABLK(1)=overlay count, DTABLK(2+)=overlay IDs
- `APOVLD`: Called from APFTN. Overlay ID in .LOCAL data block at DTABLK
- `OVLD`: Called from APAL. S-Pad 10 = overlay ID

**Procedure**:
1. `OVHNDL`: `TRAP` to `OVLAYM` with `@OVLAYM` to load all requested overlays, then `JSRT` to user entry point
2. `APOVLD`/`OVLD`: `TRAP` to `OVLAY1` with overlay segment number in DPX(0)

#### 3.9 OVLAYM/OVLAY1/OVLAY2

**Calling convention**:
- `OVLAYM`: SP7 = TCB address. Uses DTABLK in MD for overlay count and IDs
- `OVLAY1`: DPX(0) = segment number, SP7 = TCB address. Entry flag = 1 (last segment)
- `OVLAY2`: DPX(0) = segment number, SP7 = TCB address. Entry flag = 0 (not last)

**Procedure**:
1. Get overlay map pointer from TCB.OVLPTR
2. Loop through overlay map entries (8 words each) comparing segment IDs
3. When match found: set "should-be-resident" bit in RES word
4. If OVLAY2: return for more segments
5. If OVLAY1 or last OVLAYM segment: call `PSMNGR` to make all marked segments resident, then `JMP EXTASK`

### 4. Architectural Insights

#### 4.1 Interrupt Handling Microarchitecture

The code reveals several AP-120B microarchitectural details not documented in the FPS-7319 manual:

**APSTAT2 interrupt state storage**: Bits 0-2 store pre-interrupt state atomically:
- Bit 0: APMO (mode: user/supervisor)
- Bit 1: PINTU (previous universal interrupt enable)
- Bit 2: PMAS (previous MA/SMA select)

**FIFO behavior on interrupt**: The MD FIFO contains the last three reads. The save sequence must preserve FIFO order. The "FIFO swap trick" (lines after "THE FOLLOWING CODE SWAPS FIFO(1) AND FIFO(3)") swaps FIFO(1) and FIFO(3) in memory so that on restore, FIFO(1) is read first and FIFO(3) last - matching the hardware's FIFO behavior.

**SRS stack overflow protection**: The SRS restore loop (`LDSTK`) drops out one iteration early to avoid the SRS overflow interrupt that would occur if the last `JSR` pushed beyond the stack limit.

**TMRAM (Table Memory RAM)**: Device 5 (TMRAM) is used to temporarily store TM values during restore. The code writes to TMA=177776 to access a specific TM location.

#### 4.2 Floating-Point Pipeline State Reconstruction

The most architecturally significant code is the floating-point adder/multiplier save/restore:

**Adder state**: The adder has a 3-stage pipeline (A1, A2, FA). On interrupt:
1. `FPA2` pushes A2 through pipeline, saving old FA to DPX
2. `FPA1` pushes A1 through pipeline
3. The last FADD instruction opcode is saved in I/O device 376 (APSTAT3 bits 10-15)
4. On restore, the opcode is reconstructed into an instruction at `FAOLD`:
   - The FADD/FADD1 field from APSTAT3 determines the operation
   - Constants `FADARG` and `FAD1ARG` provide the instruction templates
   - `FSCLT FA` shifts the instruction to proper position
   - `WRTEXP`/`WRTMAN` write the instruction to DPX
   - Execution of `FAOLD: FADD DPX,MD` exactly reproduces the pre-interrupt adder state

**Multiplier state**: The multiplier has a 3-stage pipeline (FM0, FM1, FM2). Save/restore:
1. Each stage is saved by reading FM, then pushing pipeline with `FMUL`
2. If FPE occurred in a stage, a special constant (`UNFC`) is saved to regenerate the error on restore
3. Restore executes `FMUL` with saved operands in reverse order

#### 4.3 Context Switch Mechanism

The supervisor uses a two-level save:
- **Minimum state** (128 words): Saved immediately on interrupt. Contains all registers needed to dispatch to handlers.
- **Maximum state** (additional 128 words): Saved when switching tasks. Contains full context including floating-point state.

The save area is managed via `SYSPTR`:
- Points to next free location in system save area
- Bounds-checked against SYSAVE/SYSTOP
- On restore, adjusted back by MNSIZE

#### 4.4 Message Passing Architecture

The IPC system implements a **rendezvous model** with exchanges:
- **Exchanges** are queue headers that can hold either messages or waiting tasks (but not both simultaneously)
- **Exchange type** uses two bits: MSGBIT (messages queued) and TSKBIT (tasks queued)
- **Messages** contain: type field, priority, answer exchange address, busy bit, links
- **Answers** use a separate exchange (ANSKEY in TCB) to avoid confusion with regular messages

The `WAITA`/`TWAITA` variants demonstrate that answer waiting is a distinct operation from message waiting, using the TCB's ANSKEY field rather than an explicit exchange parameter.

### 5. Design Observations

#### 5.1 Performance Optimizations

**Cycle-counted critical paths**: The source explicitly documents timing (123-130 cycles for MNSAVE, 92-96 for MNREST). This level of optimization suggests the code was hand-tuned with a cycle-accurate simulator or hardware timer.

**Two-column loop structure**: Many loops (MXSAVE data pad save, OVLAY segment search) use a two-column format where the left column executes the operation and the right column prepares the next iteration. This exploits the AP's ability to execute two operations in parallel when they use different functional units.

**Pipeline synchronizers**: `STATMA` is used extensively as a NOP to synchronize the memory pipeline. The comment "STATISTICS: ... FAST MEMORY" suggests timing assumptions depend on memory speed.

**Register windows**: S-Pads are used as local variables with symbolic names (e.g., `TCB = 5`, `MSG = 6`). The convention of using SP0-SP7 for parameters and SP8-SP15 for local variables is consistent across all routines.

#### 5.2 Robustness Features

**Bounds checking**: SYSPTR management validates save area bounds and halts on overflow (fatal error requiring larger SYSIZE).

**Error returns**: System calls return error codes (ERRMSG, ERRBSY) for invalid operations rather than crashing.

**Atomic operations**: All critical sections assume interrupts are disabled. The comment "THIS ASSUMES SUP. MODE AND INTS. OFF." appears at the start of every routine.

**Message validation**: SEND checks that messages are unlinked (RLINK(MSG) == MSG) before sending, preventing corruption of linked lists.

#### 5.3 Memory Layout Conventions

**TCB structure**: Defined via symbolic offsets in COMSYS/SYSDEF:
- STATUS, RPRI, DPRI: Task state and priorities
- LSTMSG, ANSKEY: Message passing fields
- DPX0, SPFUNC, SP0: Register save areas
- OVLPTR: Overlay map pointer
- STAT2: APSTAT2 save area for FPE control

**Overlay map**: 8-word entries containing segment ID, PS address, size, and RES (resident) flags.

**System save area**: Bounded by SYSAVE/SYSTOP symbols, with MNSIZE defining minimum save area size.

#### 5.4 APAL Idioms

**Register-to-register moves**: `MOV 0,0; MI<SPFN` loads SPFN into MD write buffer, then `DPX<SPFN` or `LDSPI 0` completes the move. The `MOV 0,0` is a NOP that sets SPFN from SP0.

**DPX/DPY as temporary storage**: `DPX<MD` followed by later `MI<DPX` provides temporary storage without using S-Pads.

**Conditional execution**: `BZC .+2` skips the next instruction if condition is false, implementing if-then-else patterns.

**Queue manipulation**: `DEQ` and `INSERT` manipulate linked lists using DPX(2) as queue header and DPX(3) as element address. The `EMPTY` routine checks if queue is now empty after dequeue.

**Trap interface**: System calls use `TRAP` instruction with parameters in DPX/S-Pads. The trap handler dispatches to the appropriate SVC routine. Return is via `EXTASK` which restores task context.

#### 5.5 Historical Context

The code dates from March 1978 (original) through March 1979 (Super-100 version). Key observations:
- The supervisor was developed incrementally: minimum save first, then maximum save added
- The floating-point save/restore was particularly challenging (multiple bug fixes evident in comments)
- The overlay system was added later (separate $TITLE sections)
- Performance was measured in cycles and optimized aggressively for the "FAST MEMORY" option

### GLM final

(adv 102s, 8394c)

### Structured Analysis of `SYSSVC.S`

---

#### **1. Subsystem Overview**  
`SYSSVC.S` implements the AP-side supervisor's system service layer for the Super-100/Mini-100 RTOS. It handles:  
- **Context switching**: Saving/restoring AP state during interrupts/task switches.  
- **Inter-process communication (IPC)**: Message-passing via "exchanges" (queues).  
- **Task management**: Scheduling, priority adjustment, and blocking.  
- **Overlay loading**: Dynamic code swapping from MD (Main Data) to PS (Program Source) memory.  
- **Interrupt dispatching**: Hardware interrupt handling and vectoring.  

---

#### **2. Per-File Purpose**  
##### `SAVRST` (Title: SAVRST)  
- **Entries**: `MNSAVE`, `MNREST`, `MXSAVE`, `MXREST`  
- **Externals**: `TRAP`, `FATAL`, `FPE`, `IO`, `INTEXT`  
- **Purpose**: Saves/restores AP state during interrupts. `MNSAVE`/`MNREST` save/restore the minimal state (registers, FIFO). `MXSAVE`/`MXREST` save/restore full context (S-Pads, Data-Pads, FP units). Contains interrupt dispatch logic.  
- **State Manipulated**: MD FIFO, DPX/DPY write buffers, APSTAT1/2/3, S-Pad registers (SP0-SP15), TMA/TMREG, SRS (return stack), FP adder (FA/A1/A2) and multiplier (FM0-2) pipelines, hardware flags (FLAG0-3).  

##### `WAIT` (Title: WAIT)  
- **Entries**: `WAIT`, `TWAIT`, `WAITA`, `TWAITA`  
- **Externals**: `DELETE`, `DEQ`, `EMPTY`, `RECEIV`, `INSERT`, `RESUME`, `ADDCLK`  
- **Purpose**: Blocks a task waiting for a message at an exchange. Handles timed waits (`TWAIT`) and answer waits (`WAITA`).  
- **State Manipulated**: Current task’s TCB (status, answer exchange), ready/exchange queues. Scratch: SP0-6, DPX0-3.  

##### `ANSWER` (Title: ANSWER)  
- **Entries**: `ANSWER`, `MSGANS`  
- **Externals**: `SENDA`  
- **Purpose**: Sends a reply to a message. `ANSWER` replies to the last received message; `MSGANS` replies to a specified message. Validates messages (must be unlinked).  
- **State Manipulated**: Current task’s TCB, message control block. Scratch: SP0-4, DPX0-2.  

##### `SEND` (Title: SEND)  
- **Entries**: `SEND`, `SENDA`  
- **Externals**: `INSERT`, `DEQ`, `EMPTY`, `RECEIV`  
- **Purpose**: Sends a message to an exchange. Queues the message if no task is waiting; otherwise, directly delivers to a waiting task.  
- **State Manipulated**: Message control block, task TCB (priority, answer exchange), exchange queues. Scratch: SP0-4, DPX0-3.  

##### `RECEIV` (Title: RECEIV)  
- **Entries**: `RECEIV`  
- **Externals**: `RESUME`, `RMVCLK`  
- **Purpose**: Finalizes message reception by updating the task’s TCB, handling priority changes for slave tasks, clearing message busy bits, and resuming the task.  
- **State Manipulated**: Task TCB (status, message address/priority), message type. Scratch: SP0-6, DPX0-2.  

##### `RESUME` (Title: RESUME)  
- **Entries**: `RESUME`  
- **Externals**: `PRIQ`  
- **Purpose**: Reinserts a task into the ready queue by priority. Sets the task’s ready bit in its TCB.  
- **State Manipulated**: Task TCB (status), ready queue. Scratch: SP0-3, DPX1-3.  

##### `RUNPRI` (Title: RUNPRI)  
- **Entries**: `RUNPRI`, `SETPRI`  
- **Externals**: `DELETE`, `RESUME`  
- **Purpose**: Changes a task’s run priority. Uses default priority if input ≤0. Requeues task if it was in the ready queue.  
- **State Manipulated**: Task TCB (priority, status), ready queue. Scratch: SP0-4, DPX0/1/3.  

##### `SETFPE` (Title: SETFPE)  
- **Entries**: `SETFPE`  
- **Purpose**: Enables/disables floating-point exception interrupts for the current task. Modifies APSTAT2 (via I/O device 377) and the task’s saved APSTAT2.  
- **State Manipulated**: APSTAT2 (current and TCB). Scratch: SP0-3, DPX0.  

##### `OVHNDL` (Title: OVHNDL)  
- **Entries**: `OVHNDL`, `APOVLD`, `OVLD`  
- **Externals**: `OVLAY1`, `OVLAYM`  
- **Purpose**: Handles overlay loading. `OVHNDL` loads multiple overlays on `APRUN`. `APOVLD`/`OVLD` (for APFTN/APAL) request single overlays. Uses `/DOT/` common block for parameters.  
- **State Manipulated**: PS memory (via TMA), `/DOT/` common block. Scratch: SP10 (APAL), SP7 (TCB).  

##### `OVLAY` (Title: OVLAY)  
- **Entries**: `OVLAYM`, `OVLAY1`, `OVLAY2`  
- **Externals**: `EXTASK`, `PSMNGR`  
- **Purpose**: Marks overlay segments as "should-be-resident" in the task’s overlay map. `OVLAYM` handles bulk host requests; `OVLAY1`/`OVLAY2` handle single requests.  
- **State Manipulated**: Task TCB (overlay map, segment count). Scratch: SP0-7, DPX0-3.  

---

#### **3. Key Routines**  
##### `MNSAVE` (Minimum State Save)  
- **Calling Convention**: Entered via hardware interrupt. APSTAT2 holds pre-interrupt state (mode, interrupts, MA/SMA select).  
- **Side Effects**:  
  - **MD**: Saves 43 words (FIFO, DPX buffer, APSTAT1, S-Pads, DA, SPD, APSTAT2, TMA, TMREG, FFT status, MA, APSTAT3, SRS).  
  - **S-Pads**: SP0 (SMA temp), SP1-4 (calculation).  
  - **DPX**: Temp storage (SPFN, TMREG).  
  - **APSTAT**: Cleared.  
- **Cross-references**: Dispatches to `TRAP`, `FATAL`, `FPE`, `IO`, `INTEXT` based on interrupt type.  

##### `MXREST` (Maximum State Restore)  
- **Calling Convention**: Entered with SMA at end of max save area in TCB. Prefetches last saved flag.  
- **Side Effects**:  
  - **Flags**: Restores FLAG0-3 via bit manipulation.  
  - **Multiplier**: Reconstructs FM0-2 via `FMUL` with saved operands.  
  - **Adder**: Rebuilds FP adder state by re-executing last FADD instruction (from saved opcode).  
  - **Data Pads**: Restores DPYW, DPY(0-3), and 28 DPX/DPY pairs in reverse order.  
  - **S-Pads**: Restores SP8-SP15.  
- **Cross-references**: Uses `FAOLD` placeholder for reconstructed adder instruction.  

##### `WAIT` (Wait for Message)  
- **Calling Convention**: DPX0 = time limit (for `TWAIT`), DPX1 = exchange address. Returns: DPX0 = message address, SP0/SPFN = message type. Must be trapped.  
- **Side Effects**:  
  - **MD**: Reads/writes current TCB (status, answer exchange), modifies ready/exchange queues.  
  - **Scratch**: SP0-6 (TCB offsets), DPX0-3 (parameters/temp).  
- **Cross-references**: Calls `DELETE`, `DEQ`, `EMPTY`, `RECEIV`, `INSERT`, `RESUME`, `ADDCLK`.  

---

#### **4. Architectural Insights**  
- **Interrupt Management**:  
  - Minimum state save includes MD FIFO (3 deep), DPX write buffer, and DPBS mantissa bits. FIFO(1)/FIFO(3) are swapped during save for correct restore sequence.  
  - APSTAT2 encodes pre-interrupt state (mode, interrupts, MA/SMA). Interrupt dispatch uses `MOVR` on APSTAT2 bits.  
- **Floating-Point Pipeline**:  
  - FP adder/multiplier are multi-stage pipelines. Restore requires re-executing last instruction (adders) or reconstructing via `FMUL` (multipliers).  
  - FP exceptions (FPE) are masked in APSTAT2 per task.  
- **Overlay Mechanism**:  
  - Overlays are loaded from MD to PS via `PSMNGR`. Task overlay maps (8 words/segment) track "should-be-resident" status.  
  - `TRAP; DB=@OVLAYM; LDTMA` invokes overlay loading.  
- **Task Control Block (TCB)**:  
  - TCB contains status (SLVBIT, RDYBIT), priorities (RPRI, DPRI), message pointers (LSTMSG, ANSKEY), and overlay map pointer.  
- **IPC Design**:  
  - Exchanges use a 2-bit type field (MSGBIT/TSKBIT) to track messages/tasks queued. Messages are 16-bit control blocks with type/priority fields.  

---

#### **5. Design Observations**  
- **Performance Optimization**:  
  - Cycle counts in comments (e.g., `MNSAVE`: 123-148 cycles). Uses `INCMA`/`DECMA` for sequential MD access.  
  - Two-column instruction format (spacing indicates left/right columns).  
- **Error Handling**:  
  - Fatal errors (e.g., save area overflow) trigger `HALT`. Messages linked elsewhere return `ERRBSY`.  
- **Defensive Programming**:  
  - `STATMA` used as a "push" to save temp values on MD. Checks for unlinked messages via `RLINK(MSG)`.  
- **Modularity**:  
  - `$ENTRY`/`EXT` define clear interfaces (e.g., `SEND` and `ANSWER` share `SENDA`).  
  - `$INSERT COMSYS`/`SYSDEF` centralize constants.  
- **Documentation**:  
  - Detailed comments (purpose, timing, parameters). `$BOX` for structured documentation (e.g., `OVHNDL` abstract).  

---  
This analysis reveals a highly optimized, hardware-aware supervisor with sophisticated pipeline handling, efficient IPC queues, and rigorous state management. The code exemplifies 1979-era embedded systems design, prioritizing performance and correctness through manual assembly optimization.

<details><summary>Cooperative drafts</summary>

#### DS coop

Of course. Here is a structured analysis of the `SYSSVC.S` file, based on the provided APAL source code.

### 1. Subsystem Overview

This file, `SYSSVC.S`, is the core of the AP-side supervisor's system service layer for the Super-100/Mini-100 operating system. It provides the fundamental mechanisms for process management, inter-process communication (IPC), and context switching. The routines in this file are the "system calls" that user tasks (APFTN or APAL programs) invoke via traps to request services from the kernel.

The subsystem handles:
- **Context Switching:** Saving and restoring the entire AP state (minimum and maximum) during interrupts and task switches.
- **Task Synchronization & IPC:** A complete message-passing system using "exchanges" (queues). This includes `SEND`, `ANSWER`, `WAIT`, and `RECEIV` primitives.
- **Task Scheduling:** Managing the ready queue (`RESUME`, `RUNPRI`, `SETPRI`).
- **Overlay Management:** Loading code segments from Main Data (MD) memory into Program Source (PS) memory on demand (`OVHNDL`, `OVLAYM`, `OVLAY1`, `OVLAY2`).
- **Floating Point Exception Control:** Enabling/disabling the interrupt for floating-point exceptions (`SETFPE`).

### 2. Per-File Purpose

The file is a concatenation of several distinct modules, each with its own `$TITLE`.

#### Module: `SAVRST` (Title: SAVRST)
- **Public Entries:** `MNSAVE`, `MNREST`, `MXSAVE`, `MXREST`
- **Externals:** `TRAP`, `FATAL`, `FPE`, `IO`, `INTEXT`
- **Purpose:** This is the most critical module. It implements the state save and restore sequences for the entire AP-120B/FPS-100. `MNSAVE`/`MNREST` handle the "minimum state" (registers and pipeline elements needed to service an interrupt), while `MXSAVE`/`MXREST` handle the "maximum state" (the full context of a user task, including S-Pads, Data-Pads, and the floating-point adder/multiplier pipelines). It also contains the interrupt dispatch logic that determines the type of interrupt (trap, fatal, FPE, I/O, or false) and vectors to the appropriate handler.
- **AP State Manipulated:** Almost every architectural element: MD FIFO, DPX/DPY write buffers, APSTAT1/2/3, DPX/DPY registers, S-Pads (SP0-SP15), SPD, DA, TMA, TMREG, FFT status, MA, SRS (subroutine return stack), the floating-point adder (FA, A1, A2, opcode), the floating-point multiplier (FM0, FM1, FM2), and the four hardware flags (FLAG0-FLAG3).

#### Module: `WAIT` (Title: WAIT)
- **Public Entries:** `WAIT`, `TWAIT`, `WAITA`, `TWAITA`
- **Externals:** `DELETE`, `DEQ`, `EMPTY`, `RECEIV`, `INSERT`, `RESUME`, `ADDCLK`
- **Purpose:** Implements the `WAIT` system service. A task calls this to wait for a message or answer at a specific exchange. It handles timed waits (`TWAIT`, `TWAITA`) and non-timed waits. If a message is already queued, it dequeues and receives it. If not, it removes the task from the ready queue and queues it at the exchange. For timed waits with a zero limit, it returns a timeout message immediately.
- **AP State Manipulated:** Reads and writes to the current task's TCB (Task Control Block) in MD. Modifies the ready queue and exchange queues in MD. Uses S-Pads 0-6 and DPX 0-3 as scratch.

#### Module: `ANSWER` (Title: ANSWER)
- **Public Entries:** `ANSWER`, `MSGANS`
- **Externals:** `SENDA`
- **Purpose:** Implements the `ANSWER` system service. `ANSWER` sends an answer to the last message received by the current task. `MSGANS` takes a message address as a parameter and sends an answer to that specific message. It validates the message (must be unlinked), sets the answer bit in the message type, and then calls `SENDA` to deliver it.
- **AP State Manipulated:** Reads/writes to the current task's TCB and the message's control block in MD. Uses S-Pads 0-4 and DPX 0-2 as scratch.

#### Module: `SEND` (Title: SEND)
- **Public Entries:** `SEND`, `SENDA`
- **Externals:** `INSERT`, `DEQ`, `EMPTY`, `RECEIV`
- **Purpose:** Implements the `SEND` system service. `SEND` sends a message to an exchange. It validates the message, copies the task's priority into the message, and copies the message's answer exchange into the task's TCB. `SENDA` is a lower-level entry point used by `ANSWER` that skips the message validation and priority copying. Both routines check if a task is waiting at the exchange; if so, the waiting task receives the message directly; otherwise, the message is queued.
- **AP State Manipulated:** Reads/writes to the current task's TCB, the message's control block, and the exchange's type word in MD. Modifies the exchange queue. Uses S-Pads 0-4 and DPX 0-3 as scratch.

#### Module: `RECEIV` (Title: RECEIV)
- **Public Entries:** `RECEIV`
- **Externals:** `RESUME`, `RMVCLK`
- **Purpose:** A lower-level routine that performs the final steps of a task receiving a message. It is called by `SEND`/`SENDA` (when a task is waiting) and by `WAIT` (when a message is found). It copies the message address and type into the task's TCB save area, handles slave-task priority updates, clears the busy bit for answers, and then calls `RESUME` to put the task back into the ready queue and `RMVCLK` to remove it from the clock queue.
- **AP State Manipulated:** Reads/writes to the receiving task's TCB and the message's type word in MD. Uses S-Pads 0-6 and DPX 0-2 as scratch.

#### Module: `RESUME` (Title: RESUME)
- **Public Entries:** `RESUME`
- **Externals:** `PRIQ`
- **Purpose:** A low-level routine that places a task (identified by its TCB address) back into the ready queue. It sets the task's ready bit in its TCB status and then calls `PRIQ` to perform a priority-ordered insertion into the ready queue.
- **AP State Manipulated:** Reads/writes to the task's TCB status word and modifies the ready queue in MD. Uses S-Pads 0-3 and DPX 1-3 as scratch.

#### Module: `RUNPRI` (Title: RUNPRI)
- **Public Entries:** `RUNPRI`, `SETPRI`
- **Externals:** `DELETE`, `RESUME`
- **Purpose:** Implements the system service to change a task's run priority. `RUNPRI` changes the priority of the current task. `SETPRI` changes the priority of a task specified by its TCB address. If the new priority is <= 0, the task's default priority is used. If the task is currently in the ready queue, it is removed and re-inserted to maintain priority order.
- **AP State Manipulated:** Reads/writes to the task's TCB (run priority, default priority, status). Modifies the ready queue. Uses S-Pads 0-4 and DPX 0,1,3 as scratch.

#### Module: `SETFPE` (Title: SETFPE)
- **Public Entries:** `SETFPE`
- **Externals:** None
- **Purpose:** Enables or disables the floating-point exception interrupt for the current task. It modifies the FPE bit in both the current APSTAT2 register (via I/O device 377) and the saved APSTAT2 value in the task's TCB.
- **AP State Manipulated:** Reads/writes APSTAT2 via I/O device 377. Reads/writes the task's TCB in MD. Uses S-Pads 0-3 and DPX 0 as scratch.

#### Module: `OVHNDL` (Title: OVHNDL)
- **Public Entries:** `OVHNDL`, `APOVLD`, `OVLD`
- **Externals:** `OVLAY1`, `OVLAYM`
- **Purpose:** The overlay handler. `OVHNDL` is the host entry point, called during an `APRUN` call. It loads multiple overlays that were requested by the host and then jumps to a user subroutine. `APOVLD` and `OVLD` are the AP-side entry points (for APFTN and APAL, respectively) that request a single overlay segment to be made resident. They call `OVLAY1` via a trap.
- **AP State Manipulated:** Uses TMA to load overlays into PS. Reads from the `/DOT/` common block in MD. Uses S-Pad 10 (`OVID`) for the APAL entry point.

#### Module: `OVLAY` (Title: OVLAY)
- **Public Entries:** `OVLAYM`, `OVLAY1`, `OVLAY2`
- **Externals:** `EXTASK`, `PSMNGR`
- **Purpose:** The supervisor-mode overlay service routines. `OVLAYM` handles multiple overlay requests from the host. `OVLAY1` and `OVLAY2` handle single overlay requests from AP tasks. They search the task's overlay map (in its TCB) for the requested segment number, mark it as "should-be-resident", and then call `PSMNGR` to make all marked segments resident.
- **AP State Manipulated:** Reads/writes to the task's TCB (overlay map pointer, overlay map entries). Calls `PSMNGR` to manage PS memory. Uses S-Pads 0-7 and DPX 0-3 as scratch.

### 3. Key Routines

#### `MNSAVE` (Minimum State Save)
- **Calling Convention:** Entered via hardware interrupt. Mode is Supervisor, Memory Select is SMA, Universal Interrupts are inhibited. APSTAT2 bits 0-2 contain pre-interrupt state.
- **Side Effects:**
    - **MD:** Writes 43 words of minimum state to the system save area (starting at `SYSPTR`). This includes MD FIFO, DPX write buffer, APSTAT1, DPX(0-3), DA, SPD, SP(0-7), SPFN, APSTAT2, TMA, TMREG, FFT status, MA, APSTAT3, and SRS(15-0).
    - **S-Pads:** SP0 is used as a temporary for SMA. SP1, SP2, SP3, SP4 are used for calculations.
    - **DPX:** DPX is used as a temporary store for SPFN, TMREG, and other values.
    - **APSTAT:** APSTAT is cleared to allow TM references.
    - **SRS:** The subroutine return stack is read and saved to MD.
- **Cross-references:** Calls `TRAP`, `FATAL`, `FPE`, `IO`, `INTEXT` based on interrupt type. Uses `$INSERT COMSYS` for system constants.

#### `MXREST` (Maximum State Restore)
- **Calling Convention:** Entered with SMA pointing to the end of the max save area in the TCB. A read has been initiated, pre-fetching the last saved flag.
- **Side Effects:**
    - **Flags:** Restores FLAG0-FLAG3 from saved values in MD.
    - **Multiplier:** Restores the 3-stage floating-point multiplier pipeline (FM0, FM1, FM2) by executing `FMUL` instructions with the saved operands.
    - **Adder:** Restores the floating-point adder state. This is complex: it reconstructs the last FADD instruction from a saved opcode, normalizes/unnormalizes the old FA value, and executes the reconstructed instruction to restore the pipeline.
    - **Data Pads:** Restores DPYW, DPY(0-3), and the remaining 28 DPX/DPY pairs.
    - **S-Pads:** Restores S-Pads 8-15.
- **Cross-references:** Uses `$INSERT COMSYS` for constants. The `FAOLD` label is used as a placeholder for the reconstructed adder instruction.

#### `WAIT` (Wait for Message)
- **Calling Convention:** Parameters are passed in DPX(0) (time limit for `TWAIT`) and DPX(1) (exchange address). Returns with DPX(0) = message address, SP0 and SPFN = message type. Cannot be called via `JSR`; must be via trap.
- **Side Effects:**
    - **MD:** Reads/writes the current task's TCB (status, answer exchange). Modifies the ready queue (via `DELETE`). Modifies the exchange queue (via `DEQ`, `INSERT`). Modifies the clock queue (via `ADDCLK`).
    - **S-Pads:** SP 0-6 are used as scratch.
    - **DPX:** DPX 0-3 are used for parameters and scratch.
- **Cross-references:** Calls `DELETE`, `DEQ`, `EMPTY`, `RECEIV`, `INSERT`, `RESUME`, `ADDCLK`.

#### `SEND` (Send Message)
- **Calling Convention:** Parameters are in DPX(0) = message address, DPX(1) = exchange address. No return value.
- **Side Effects:**
    - **MD:** Reads/writes the message's control block (type, priority, answer exchange). Reads/writes the current task's TCB (priority, answer exchange). Modifies the exchange queue (via `INSERT`, `DEQ`). Modifies the ready queue (via `RECEIV`).
    - **S-Pads:** SP 0-4 are used as scratch.
    - **DPX:** DPX 0-3 are used for parameters and scratch.
- **Cross-references:** Calls `INSERT`, `DEQ`, `EMPTY`, `RECEIV`.

#### `RECEIV` (Receive Message)
- **Calling Convention:** Parameters are in DPX(0) = message address, DPX(1) = TCB address. Returns with DPX(0) = message address, SP0 and SPFN = message type.
- **Side Effects:**
    - **MD:** Reads/writes the receiving task's TCB (status, run priority, last message received, DPX0 save area, SPFN/SP0 save areas). Clears the message's busy bit if it's an answer.
    - **S-Pads:** SP 0-6 are used as scratch.
    - **DPX:** DPX 0-2 are used for parameters and scratch.
- **Cross-references:** Calls `RESUME`, `RMVCLK`.

### 4. Architectural Insights

This code reveals several deep insights into the AP-120B/FPS-100 architecture that go beyond the standard manual:

- **Interrupt Handling and State Management:** The `SAVRST` module is a masterclass in managing a deeply pipelined, parallel architecture. The "minimum state" is not just registers; it includes the MD FIFO (3 deep), the DPX write buffer, and the DPBS (Data Pad Bus) mantissa bits. The order of save/restore is critical, as noted in the comments. The code swaps FIFO(1) and FIFO(3) during save so that during restore, the FIFO is filled in the correct order (FIFO(1) out first, FIFO(3) out last). This shows a deep understanding of the memory pipeline.
- **Floating-Point Pipeline Restoration:** The code for saving and restoring the floating-point adder and multiplier is exceptionally sophisticated. It doesn't just save the final result; it saves the intermediate pipeline stages (FA, A1, A2 for the adder; FM0, FM1, FM2 for the multiplier). The restore sequence for the adder is particularly clever: it reconstructs the exact last floating-point instruction from a saved opcode and re-executes it with the saved operands to perfectly restore the pipeline state, including potential overflow/underflow conditions. This implies the AP's floating-point units have a visible, multi-stage pipeline that can be frozen and restored.
- **Interrupt Dispatch via APSTAT2:** The interrupt dispatch logic in `MNSAVE` uses the `MOVR` instruction to test bits in a value read from APSTAT2 (via I/O device 377). This confirms that APSTAT2 is a key register for interrupt status, with specific bits for TRAP, FATAL, FPE, and I/O interrupts. The "false interrupt" counter (`LOGITS`) suggests a mechanism for handling spurious or unclaimed interrupts.
- **System Save Area Management:** The code dynamically manages a system save area in MD (`SYSAVE` to `SYSTOP`). It uses a pointer (`SYSPTR`) to track the next free location. The logic for setting `SYSPTR` in `MNSAVE` and `MNREST` is defensive, checking for overflow and underflow of the save area, halting on fatal errors. This reveals a memory management scheme for critical kernel data.
- **Task Control Block (TCB) Structure:** The code heavily references offsets into the TCB (e.g., `STATUS`, `RPRI`, `DPRI`, `LSTMSG`, `ANSKEY`, `DPX0`, `SPFUNC`, `OVLPTR`). This provides a detailed map of the TCB layout, which is a central data structure for the OS. It contains status flags, priorities, saved register values, message pointers, and overlay management information.
- **Exchange-Based IPC:** The message-passing system is built on "exchanges," which are essentially queue headers. The exchange type word (`TYPE`) uses two bits (`MSGBIT` and `TSKBIT`) to indicate whether messages or tasks are queued. This is a simple but effective state machine for managing synchronous and asynchronous communication.
- **Overlay Mechanism:** The overlay handler (`OVHNDL`, `OVLAY`) reveals that the AP can load code from MD into PS at runtime. The `TRAP; DB=@OVLAYM; LDTMA` instruction sequence is a trap that invokes the supervisor to manage this. The overlay map in the TCB is an 8-word entry per segment, with a "should-be-resident" bit that is set before calling the PS manager (`PSMNGR`). This implies a software-managed overlay scheme, not a hardware MMU.

### 5. Design Observations

- **Performance-Critical Assembly:** The code is meticulously hand-optimized. The comments include cycle counts for every routine, showing a deep concern for performance. The use of `INCMA` (increment and access MD) and `DECMA` (decrement and access MD) in tight loops is a key optimization for sequential memory access.
- **Two-Column Instruction Format:** The code heavily uses the AP's ability to execute two instructions in parallel per cycle. The spacing in the source code (e.g., in the `LOOPM` and `LOOP` routines) visually separates the left and right columns of the instruction word. This is a hallmark of APAL programming.
- **Clever Use of `STATMA`:** The `STATMA` instruction (store MA to MD) is used frequently as a "push" operation to save values on a stack in MD. This is a common idiom for temporary storage when S-Pads are scarce.
- **Defensive Programming:** The code includes numerous checks for error conditions (e.g., message linked elsewhere, no last message received, system save area overflow). These errors often result in a `HALT` or a jump to an error handler (`ERR1`, `ERR2`), indicating a robust, fail-stop design.
- **Modularity via `$ENTRY` and `$EXT`:** The file is structured as a series of modules, each with clearly defined entry points and external references. This promotes code reuse and separation of concerns. For example, `SEND` and `ANSWER` both call the lower-level `SENDA`, and `WAIT` and `SEND` both call `RECEIV`.
- **Use of `$INSERT` for Common Definitions:** The `$INSERT COMSYS` and `$INSERT SYSDEF` directives are used to include system-wide constants and definitions. This is a standard practice for managing complexity in assembly-language projects.
- **Commenting Style:** The comments are extensive and informative. They include high-level procedure descriptions, calling conventions, register usage, timing information, and even historical notes. The `$BOX` directives in the overlay handler are used to create structured documentation blocks within the source code. This level of documentation is exceptional for assembly code from this era.

#### GLM coop

### Structured Analysis of SYSSVC.S

---

#### 1. **Subsystem Overview**
`SYSSVC.S` implements the core **system service routines** for the AP-side supervisor (Super-100/Mini-100 mode). It handles:
- **Context switching** via state save/restore sequences.
- **Interrupt dispatching** to handlers (TRAP, FATAL, FPE, IO, INTEXT).
- **Inter-task communication** using message passing (SEND, WAIT, ANSWER).
- **Task management** (priorities, ready queues, clocked waits).
- **Overlay loading** for dynamic memory management.
- **Floating-point exception control**.

This subsystem forms the **kernel of the AP's autonomous OS**, enabling multi-tasking, interrupt-driven execution, and host-transparent operation without direct host CPU intervention.

---

#### 2. **Per-File Purpose**
| Title       | Public Entries     | Externals                     | Purpose                                                                 | Architectural State Manipulated                                                                 |
|-------------|--------------------|-------------------------------|-------------------------------------------------------------------------|------------------------------------------------------------------------------------------------|
| **SAVRST**  | `MNSAVE`, `MNREST`<br>`MXSAVE`, `MXREST` | `TRAP`, `FATAL`,<br>`FPE`, `IO`,<br>`INTEXT` | Minimum/maximum state save/restore during interrupts.                    | S-Pads, DPX/DPY, MD FIFO, TM, APSTAT1/2/3, SRS, MA, SPAD stack, floating-point unit.        |
| **WAIT**    | `WAIT`, `TWAIT`<br>`WAITA`, `TWAITA` | `DELETE`, `DEQ`,<br>`EMPTY`, `RECEIV`<br>`INSERT`, `RESUME`, `ADDCLK` | Waits for messages/answers; supports timed waits.                       | TCBs, exchange queues, ready queue, clock queue.                                               |
| **ANSWER**  | `ANSWER`, `MSGANS` | `SENDA`                       | Sends answers to messages; validates message state.                     | TCB last-message field, message type, answer exchanges.                                        |
| **SEND**    | `SEND`, `SENDA`    | `INSERT`, `DEQ`,<br>`EMPTY`, `RECEIV` | Sends messages to exchanges; wakes waiting tasks.                       | Exchange queues, message type, task priority, TCB status.                                      |
| **RECEIV**  | `RECEIV`           | `RESUME`, `RMVCLK`           | Receives messages; reinserts tasks into ready queue.                    | TCB message fields, ready queue, message priority, S-PAD 0/SPFN.                             |
| **RESUME**  | `RESUME`          | `PRIQ`                       | Inserts task into ready queue.                                         | TCB ready bit, ready queue.                                                                   |
| **RUNPRI**  | `RUNPRI`, `SETPRI`| `DELETE`, `RESUME`           | Sets task priority; reorders task in ready queue if needed.              | TCB priority, default priority, ready queue.                                                   |
| **SETFPE**  | `SETFPE`          | -                            | Enables/disables floating-point exception interrupts.                   | APSTAT2, TCB APSTAT2.                                                                        |
| **OVHNDL**  | `OVHNDL`,<br>`APOVLD`,<br>`OVLD` | `OVLAY1`, `OVLAYM`        | Loads overlays; called by host (APRUN) or tasks.                        | Overlay map, PS (Program Source) memory, task entry points.                                   |
| **OVLAY**   | `OVLAYM`,<br>`OVLAY1`,<br>`OVLAY2` | `PSMNGR`, `EXTASK`      | Marks overlays as should-be-resident; triggers PS manager.              | Overlay map in TCB, resident flags, segment counts.                                            |

---

#### 3. **Key Routines**
##### a. **SAVRST (State Save/Restore)**
- **`MNSAVE`**:
  - **Calling Conv.**: No params; returns via jump to interrupt handler.
  - **Side Effects**: Saves 128 words (FIFO, DPX, SPADs, APSTAT, SRS, MA, TMA) in 123-130 cycles. Sets `SYSPTR` and jumps to `TRAP`/`FATAL`/`FPE`/`IO`/`INTEXT`.
  - **Cross-ref**: Uses external interrupts for dispatch.

- **`MXSAVE`**:
  - **Calling Conv.**: Enters with SMA at TCB save area start.
  - **Side Effects**: Saves 64 more words (S-PADs 0-7, DPY, DPA, floating-point unit, flags). Takes 145-148 cycles.
  - **Arch Insight**: Floating-point state saved as instructions to reconstruct FA/FM on restore.

##### b. **WAIT/TWAIT**
- **`WAIT`**:
  - **Calling Conv.**: DPX(1)=exchange address. For `TWAIT`, DPX(0)=time limit.
  - **Side Effects**: Removes task from ready queue. If no message, queues task at exchange or clock queue.
  - **Arch Insight**: Uses `ANSKEY` in TCB for answer waits; `EMPTY`/`DEQ`/`RECEIV` for message delivery.

- **`TWAIT`** (timed wait):
  - **Side Effects**: If time limit=0, returns timeout message immediately via `RESUME`.

##### c. **SEND/SENDA**
- **`SEND`**:
  - **Calling Conv.**: DPX(0)=message addr, DPX(1)=exchange addr.
  - **Side Effects**: Validates message unlinkedness. If tasks waiting at exchange, dequeues task and calls `RECEIV`; else queues message.
  - **Arch Insight**: Exchange type bits (`TSKBIT`/`MSGBIT`) track queued tasks/messages.

##### d. **RECEIV**
- **Calling Conv.**: DPX(0)=message addr, DPX(1)=TCB addr.
- **Side Effects**: Updates TCB's last-message field, message type, and reinserts task into ready queue via `RESUME`. Clears busy bit for answers.
- **Arch Insight**: `RMVCLK` removes task from clock queue if waiting for time limit.

##### e. **OVHNDL/OVLAY**
- **`OVHNDL`**:
  - **Calling Conv.**: Called via `APRUN`; uses `DTABLK` in MD for overlay IDs/count.
  - **Side Effects**: Loads multiple overlays into PS, then jumps to user entry point.
  
- **`OVLAY1`/`OVLAY2`**:
  - **Calling Conv.**: DPX(0)=segment ID.
  - **Side Effects**: Marks overlay as should-be-resident in TCB's overlay map. Triggers `PSMNGR` to load overlays.

---

#### 4. **Architectural Insights**
- **Interrupt Management**:
  - **Min/Max State Save**: Critical for low-latency interrupt handling. `MNSAVE` saves only essential registers (123 cycles); `MXSAVE` saves full context including floating-point state (148 cycles).
  - **Interrupt Dispatch**: `APSTAT2` stores pre-interrupt state (mode, interrupt enable, MA/SMA). Code jumps to handlers based on interrupt type.

- **Context Switching**:
  - **TCB Structure**: Save areas for min/max state, overlay map, priority, message queue pointers.
  - **Floating-Point Unit**: State saved/restored by reconstructing instructions from stored operands. Overflows/underflows handled via special constants.

- **Message Passing**:
  - **Rendezvous Model**: Tasks block at exchanges (`WAIT`) until messages arrive (`SEND`). Answers use dedicated `ANSKEY` in TCB.
  - **Exchange Types**: Tracks if messages/queued tasks are present via `MSGBIT`/`TSKBIT`.

- **Overlay Management**:
  - **PS Memory**: Segments dynamically loaded from MD to PS via overlay map in TCB. `RES` bit marks should-be-resident segments.

- **Task Scheduling**:
  - **Priority Queues**: `PRIQ` inserts tasks by priority. `RUNPRI` reorders tasks if priority changes.
  - **Clocked Waits**: `ADDCLK` enqueues tasks in clock queue; `RMVCLK` removes them on timeout.

---

#### 5. **Design Observations**
- **Performance Optimizations**:
  - **Cycle-Counted Code**: Critical paths (e.g., `MNSAVE` in 130 cycles) minimize interrupt latency.
  - **Register Windows**: S-PADs used for local variables (e.g., `LOOPM` in `WAIT` uses SP 5-7).
  - **In-Place Queue Operations**: `DEQ`/`INSERT` directly manipulate links to avoid copying entire queues.

- **Robustness**:
  - **Error Handling**: Returns `ERRMSG`/`ERRBSY` for invalid operations (e.g., sending busy message).
  - **Atomic Operations**: Interrupts disabled during critical sections (e.g., queue manipulation).

- **Memory Layout**:
  - **Fixed Symbols**: `SYSTOP`/`SYSAVE` define system save area bounds; `MNSIZE` sizes min save area.
  - **TCB Offsets**: Symbolic constants (e.g., `LSTMSG`, `ANSKEY`) define TCB field positions.

- **Idioms**:
  - **Two-Column Loops**: Used in `MXSAVE` and `OVLAY2` for efficient memory access (e.g., `INCMA; MI<DPX`).
  - **DPX as Stack**: `RDPI`/`WDPI` save/restore DPX write buffer across calls.
  - **Flag Manipulation**: `BFLx`/`SFLx` test/set task/exchange flags.

---

This code reveals a sophisticated, highly optimized 1979 embedded OS kernel with careful attention to cycle counts, atomicity, and minimal state for fast interrupts. The architecture heavily leverages S-PAD windows, DPX/DPY for parameter passing, and memory-mapped queues.

</details>



---

## Group: `kernel_io`

**I/O queue + Host-RPC endpoints**

Files: `IOQUE.S`, `HIRP.S`, `HSVC.S`, `HIRPM.S`, `HSVCM.S`

### DeepSeek final

(adv 101s, 27085c)

## Critique of GLM Analysis

The GLM analysis is generally accurate but has several issues:

1. **Incorrect file grouping**: HIRPM.S and HSVCM.S are NOT "RTS100 mode" variants - they are the **Mini-100** (smaller, simpler supervisor) versions, while HIRP.S and HSVC.S are the **Super-100** (full MTS100) versions. The file headers clearly state "MTS100" vs "RTS100" but these are different supervisor products, not modes.

2. **Missing architectural details**: The analysis doesn't explain the critical difference in how MTS100 uses message exchanges (EXAPEX, EXFUNC) while Mini-100 uses direct datum storage - this reveals fundamentally different tasking models.

3. **Incorrect timing analysis**: The 11-cycle timing for INSERT includes memory waits that are architecture-dependent; the actual instruction count is more relevant.

4. **Missing key insight**: The `$ISR 7` directive in HIRP.S and HIRPM.S is critical - it tells the assembler this is interrupt service routine for IRQ level 7, which affects how the assembler generates entry/exit code.

5. **Overlooked architectural feature**: The `SWDB` instruction in APXMT reads the SWR (Status Word Register) directly to the Data Bus - this is a special I/O operation not documented in standard AP-120B manuals.

## Final Reference Analysis

---

# Structured Analysis: `kernel_io` Subsystem

## 1. Subsystem Overview

The `kernel_io` subsystem implements the **AP-side communication infrastructure** for the FPS-100 supervisor, supporting two distinct supervisor products:

- **Super-100 (MTS100)**: Full multi-tasking supervisor with message-passing between tasks
- **Mini-100 (RTS100)**: Lightweight real-time supervisor with simplified datum-only communication

The subsystem provides:
- **Doubly-linked queue management** for I/O driver scheduling and task management
- **Host interrupt service** for receiving commands and data from the host computer
- **Host communication services** for sending data back to the host
- **Device configuration** for mapping physical I/O devices to interrupt masks

The code runs entirely on the AP processor, managing the AP's Main Data memory, Data Pads, and S-Pad registers. It interfaces with the host through the AP's Status Word Register (SWR) and LITES register, using APSTAT3 for synchronization.

---

## 2. Per-File Purpose

### IOQUE.S (216 lines) - I/O Queue Support Routines

**$TITLE entries**: `INSERT`, `EMPTY`, `DELETE`, `ENABLE`

**$ENTRY declarations**:
- `INSERT,0` - Insert node into doubly-linked queue
- `EMPTY,0` - Test if queue has successor elements
- `DELETE,0` - Remove node from doubly-linked queue  
- `ENABLE` - Find interrupt mask for I/O device

**$EXT references**: None (uses `$COMMON /CONFIG/` and `$COMMON /ISRMAP/`)

**Purpose**: Provides low-level queue manipulation primitives used by the I/O subsystem and task scheduler. The `ENABLE` routine maps physical device addresses to interrupt mask bits via a configuration table.

**AP state manipulated**:
- **MD (Main Data)**: Queue link fields (RLINK at offset 0, LLINK at offset 1), device configuration table (`/CONFIG/`), interrupt service routine map (`/ISRMAP/`)
- **DPX (Data Pad X)**: Node addresses passed in DPX(2), DPX(3); results in DPX(2), DPX(3)
- **SPAD**: Error codes in SPAD0 and SPFN; scratch registers SP 0-3

**Key architectural detail**: Queue nodes use a fixed layout: word 0 = RLINK (right/next pointer), word 1 = LLINK (left/previous pointer). This is the standard FPS-100 message queue format used throughout the supervisor.

---

### HIRP.S (326 lines) - Host Interrupt Service (Super-100/MTS100)

**$TITLE**: `HIRP`

**$ENTRY**: `HIRP,0` (interrupt service routine for IRQ level 7)

**$EXT references**: `SEND`, `WATSWR` (from HSVC.S), `$INSERT FHOSTC` (common data definitions)

**$ISR 7**: Declares this as IRQ level 7 handler - the assembler generates prologue/epilogue code

**Purpose**: Processes all host-initiated communication in the Super-100 environment. Handles three command types:
1. **SPLDGO** (option=1): Load SPAD values from host into memory buffer
2. **RUNAP** (option=2): Send message to APEX task for execution
3. **FUNCTION INTERPRET** (option=3): Send message to FUNC interpreter task

Also handles **datum updates** (7 numbered slots for real-time data exchange).

**AP state manipulated**:
- **MD**: Message buffers (`APMSG` - 11 words), message exchanges (`EXAPEX`, `EXFUNC`, `EXDAT1-7`), datum storage (`VDATM`), SPAD save area (`FSPAD`)
- **DPX**: Message addresses in X0, exchange addresses in X1, datum values in X1
- **SPAD**: R0-R5 for parameters; R0 cleared to re-enable host IRP
- **SWR**: Read via `SWDB` instruction in `APXMT`
- **APSTAT3**: Polled for host synchronization

**Data structures defined**:
- `APMSG`: 11-word message buffer with RT/LLINK, priority, type, length, answer key, option, SPAD count, SWR value, function value
- `EXAPEX`/`EXFUNC`: 6-word message exchanges for task communication
- `EXDAT1-7`: 6-word exchanges for datum slots
- `MGDAT1-7`: 7-word message buffers for datum values
- `VDATM`: 21-word table mapping datum slots to their storage, message buffers, and exchanges

---

### HSVC.S (209 lines) - Host Communication Services (Super-100/MTS100)

**$TITLE**: `HSVC`

**$ENTRY declarations**: `WATSWR`, `SENDER`, `FPUT`, `FGET`, `FTST`

**$EXT references**: `WAIT`, `TWAIT` (external task synchronization primitives)

**Purpose**: Provides the communication primitives for host-AP interaction in the Super-100 environment:
- **WATSWR/WATLIT**: Poll APSTAT3 for host synchronization flags
- **SENDER**: Send 1-3 word messages to host via LITES register
- **FPUT**: Send datum value to specific host slot
- **FGET**: Receive datum value from host (blocks until available)
- **FTST**: Test if datum value is available (non-blocking)

**AP state manipulated**:
- **MD**: VDATM table for datum storage
- **DPX**: Message words in X0-X2
- **SPAD**: R0-R5 for parameters and results
- **APSTAT3**: Read via `IN; DB=INBS` instruction for synchronization
- **LITES register**: Written via `DBLLIT` instruction for host communication
- **CTRL register**: Bit 5 set via `INTEN` to interrupt host

**Key architectural feature**: The `WAIT` and `TWAIT` externals are task synchronization primitives - `WAIT` blocks indefinitely on a message exchange, `TWAIT` has a timeout. This reveals the Super-100's tasking model uses message exchanges for inter-task communication.

---

### HIRPM.S (96 lines) - Host Interrupt Service (Mini-100/RTS100)

**$TITLE**: `HIRP`

**$ENTRY**: `HIRP,0` (interrupt service routine for IRQ level 7)

**$EXT references**: `WATSWR` (from HSVCM.S), `$INSERT MINDEF` (Mini-100 definitions)

**$ISR 7**: Same IRQ level as Super-100 version

**Purpose**: Simplified host interrupt handler for the Mini-100 environment. Only handles **datum updates** - no task message dispatching. The Mini-100 does not support APEX or FUNC interpreter tasks.

**AP state manipulated**:
- **MD**: VDATM (7 words only - no message buffers or exchanges)
- **DPX**: Datum value in X1
- **SPAD**: R0-R2 for processing; R0 cleared to re-enable host IRP
- **SWR**: Read via `SWDB` instruction

**Key differences from HIRP.S**:
- No `APMSG`, `EXAPEX`, `EXFUNC`, `MGDAT1-7` data structures
- VDATM is only 7 words (datum values only, no message buffer pointers)
- No `SEND` external call - datum is stored directly
- Interrupts disabled (`IOFF`) during the critical store operation
- No SPAD loading or function dispatch logic

---

### HSVCM.S (200 lines) - Host Communication Services (Mini-100/RTS100)

**$TITLE**: `HSVC`

**$ENTRY declarations**: `WATSWR`, `SENDER`, `FPUT`, `FGET`, `FTST`, `WATLIT`

**$EXT references**: None (self-contained)

**Purpose**: Communication primitives for the Mini-100 environment. Similar to HSVC.S but:
- No external `WAIT`/`TWAIT` references - uses polling instead
- `FGET` polls VDATM directly rather than waiting on message exchanges
- `FTST` uses simpler polling loop without timed wait

**AP state manipulated**:
- **MD**: VDATM (7 words)
- **DPX**: Message words in X0-X2
- **SPAD**: R0-R5 for parameters and results
- **APSTAT3**: Read for synchronization
- **LITES register**: Written for host communication

**Key differences from HSVC.S**:
- `FGET` uses busy-wait polling (`FG200` loop) instead of `WAIT` external
- `FTST` uses `NOP` for memory timing instead of `TWAIT` external
- No message exchange infrastructure - datum slots are simple memory locations
- `WATLIT` is a public entry point (not in HSVC.S)

---

## 3. Key Routines

### INSERT (IOQUE.S)

**Calling convention**:
- Input: `DPX(2)` = address of NEXT element, `DPX(3)` = address of NEW element
- Output: `SPAD0` and `SPFN` = 0 (success) or non-zero (error: NEW already linked)
- Scratch: SP 0-3, DPX 2-3

**Algorithm**:
1. Verify NEW is unlinked (RLINK(NEW) points to itself)
2. Set LLINK(NEXT) = NEW
3. Set RLINK(NEW) = NEXT
4. Set LLINK(NEW) = LAST (from LLINK(NEXT))
5. Set RLINK(LAST) = NEW

**AP side effects**:
- Reads: MD[NEW+0], MD[NEXT+0], MD[NEXT+1]
- Writes: MD[NEXT+1], MD[NEW+0], MD[NEW+1], MD[LAST+0]
- SPAD: SP0 set to 0 or non-zero, SPFN set same

**Cross-references**: Used by I/O driver subsystem and task scheduler for queue management. The queue format (RLINK at +0, LLINK at +1) is the standard FPS-100 message queue format.

**Timing**: 11 cycles (successful), 7 cycles (error - early exit)

---

### EMPTY (IOQUE.S)

**Calling convention**:
- Input: `DPX(2)` = address of queue header or element
- Output: `DPX(3)` = address of NEXT element, `SPAD0` and `SPFN` = 0 if empty (no successor)

**Algorithm**: Compare RLINK(element) with element itself - if equal, queue is empty.

**AP side effects**:
- Reads: MD[DPX(2)+0] (RLINK)
- Writes: DPX(3) with next element address
- SPAD: SP0 = 0 if empty, non-zero if not empty

**Cross-references**: Used to test if I/O queues have pending work.

**Timing**: 5 cycles

---

### DELETE (IOQUE.S)

**Calling convention**:
- Input: `DPX(3)` = address of element to delete
- Output: `DPX(2)` = address of NEXT element (deleted element's successor)
- SPAD0 is preserved

**Algorithm**:
1. Get RLINK(OUT) = NEXT
2. Get LLINK(OUT) = LAST
3. Set LLINK(NEXT) = LAST
4. Set RLINK(LAST) = NEXT
5. Set RLINK(OUT) = OUT (mark as unlinked)

**AP side effects**:
- Reads: MD[DPX(3)+0], MD[DPX(3)+1]
- Writes: MD[NEXT+1], MD[LAST+0], MD[DPX(3)+0]
- DPX: DPX(2) set to NEXT address

**Cross-references**: Used to remove completed I/O operations from queues.

**Timing**: 7 cycles

---

### ENABLE (IOQUE.S)

**Calling convention**:
- Input: `R0` = physical device address
- Output: `R4` = interrupt mask bit (0 if device not found)
- Scratch: R1-R4, DPX registers

**Algorithm**:
1. Search `/CONFIG/` table (15 entries, 5 words each)
2. Compare device address (word 4 of each entry)
3. If found, return bit mask (word 2)
4. If not found, return 0

**AP side effects**:
- Reads: `/CONFIG/` common block in MD
- SPAD: R0-R4 modified
- DPX: Used internally for memory addressing

**Cross-references**: Called during system initialization to configure I/O device interrupts. The `/ISRMAP/` common block (word 3 of each entry) contains pointers to service routines in the overlay map.

**Configuration table format** (5 words per device):
```
Word 0: Priority mask
Word 1: Bit mask (this device's interrupt bit)
Word 2: Pointer to service routine in overlay map
Word 3: Device order number (EXP) / Physical device address (LMAN)
Word 4: Save area for old IMASK
```

---

### HIRP (HIRP.S) - Host Interrupt Service Routine

**Calling convention**: Interrupt handler - called by hardware on host IRQ. Returns with `R0=0` to re-enable host IRP.

**Algorithm**:
1. Enable interrupts (`ION`)
2. Read SWR via `APXMT` to get first word from host
3. If SWR bit 0 set (datum value), jump to `DATUM` handler
4. Otherwise, read option word, SPAD count, SWR value, function value
5. Dispatch based on option:
   - Option 1 (SPLDGO): Read SPAD values from host into `FSPAD` buffer, then send to APEX
   - Option 2 (RUNAP): Send message to APEX task
   - Option 3 (FUNCTION): Send message to FUNC interpreter task

**AP side effects**:
- Reads: SWR register (4-5 times per interrupt)
- Writes: `APMSG` buffer fields, `FSPAD` buffer
- SPAD: R0-R5 heavily modified
- DPX: X0, X1 used for message/exchange addresses
- Calls: `APXMT` (internal), `SEND` (external from HSVC.S)

**Cross-references**: 
- Calls `WATSWR` (HSVC.S) for synchronization
- Calls `SEND` (HSVC.S) for message delivery
- Uses `APMSG`, `EXAPEX`, `EXFUNC` data structures

**Host communication protocol** (words read in order):
1. First word: Datum value (if bit 0 set) or function code
2. Option word (1=SPLDGO, 2=RUNAP, 3=FUNCTION)
3. SPAD count (number of SPAD values to follow)
4. SWR value
5. Function value (for FUNC option) or start address

---

### APXMT (HIRP.S and HIRPM.S) - Read Value from Host

**Calling convention**:
- Input: None
- Output: `R1` and `DPX(X1)` = 16-bit value from SWR
- Preserves: R3-R7, X2-X3

**Algorithm**:
1. Call `WATSWR` to wait for host to write SWR
2. Execute `SWDB` instruction to read SWR to Data Bus
3. Transfer to DPX(X1) and R1

**AP side effects**:
- Reads: SWR register via `SWDB` instruction
- Writes: DPX(X1), R1
- Calls: `WATSWR` (external)

**Cross-references**: Used by both Super-100 and Mini-100 interrupt handlers.

**Architectural note**: The `SWDB` instruction is a special AP-120B I/O operation that reads the Status Word Register directly to the Data Bus. This is not a standard memory-mapped I/O operation.

---

### WATSWR (HSVC.S and HSVCM.S) - Wait for Host to Write SWR

**Calling convention**:
- Input: None
- Output: None (busy-waits until condition met)
- Scratch: R0, R1

**Algorithm**:
1. Load mask for SWR bit (4000 octal = bit 11 of APSTAT3)
2. Read APSTAT3 via `IN; DB=INBS` instruction
3. AND with mask
4. Loop while bit is set (host has not read the SWR)

**AP side effects**:
- Reads: APSTAT3 register (device address `APST3`)
- SPAD: R0, R1 modified

**Cross-references**: Called by `APXMT` in both HIRP.S and HIRPM.S.

**Architectural note**: APSTAT3 bit 4000 (octal) is the "SWR written" flag. The host sets this bit when it writes to the SWR; the AP clears it by reading the SWR. This is a hardware handshake mechanism.

---

### SENDER (HSVC.S and HSVCM.S) - Send Message to Host

**Calling convention**:
- Input: `DPX(X0)` = first message word, `DPX(X1)` = second word (optional), `DPX(X2)` = third word (optional)
- Output: None

**Algorithm**:
1. Wait for host to read previous LITES value (`WATLIT`)
2. Write first word to LITES register (`DBLLIT`)
3. Disable interrupts
4. Set CTRL bit 5 to interrupt host (`INTEN`)
5. If first word is zero (multi-word message), send second and third words
6. Re-enable interrupts

**AP side effects**:
- Writes: LITES register via `DBLLIT` instruction
- Writes: CTRL register bit 5 via `INTEN` instruction
- SPAD: R1 modified
- Interrupts: Disabled then re-enabled

**Cross-references**: Called by `FPUT` and directly by `HIRP` for sending messages.

**Architectural note**: The `DBLLIT` instruction writes the Data Bus to the LITES register, which the host can read. The `INTEN` instruction sets CTRL bit 5, which generates an interrupt to the host. This is the AP-to-host communication mechanism.

---

### FPUT (HSVC.S and HSVCM.S) - Send Datum to Host

**Calling convention**:
- Input: `R1` = destination slot (3 bits, 1-7), `R2` = datum value (13 bits)
- Output: None
- Scratch: R0

**Algorithm**:
1. Mask R1 to 3 bits
2. If destination is 0, return (no-op)
3. Shift datum left by 3 bits
4. OR in destination bits
5. Store in DPX(X0) and call SENDER

**AP side effects**:
- SPAD: R0, R1, R2 modified
- DPX: X0 set to encoded datum
- Calls: SENDER

**Cross-references**: Used by application tasks to send data to host.

**Data format**: 16-bit word: bits 15-13 = destination (3 bits), bits 12-0 = datum (13 bits)

---

### FGET (HSVC.S) - Get Datum from Host (Super-100)

**Calling convention**:
- Input: `R1` = source slot (1-7)
- Output: `R2` = flag (0=success, +1=invalid slot, -1=slot 0), `R3` = datum value
- Scratch: R0-R3, DPX X0-X3

**Algorithm**:
1. Validate source slot (1-7 only)
2. Get exchange address from VDATM table
3. Call `WAIT` external to block on message exchange
4. Critical section: read datum value, clear memory, set flag=0
5. Shift datum right 3 bits to remove destination field
6. Re-enable interrupts

**AP side effects**:
- Reads: VDATM table, message exchange
- Writes: VDATM datum slot (cleared to zero)
- SPAD: R0-R3 modified
- DPX: X0-X3 used
- Interrupts: Disabled during critical section

**Cross-references**: Uses `WAIT` external (task synchronization primitive from scheduler).

**Architectural note**: The Super-100 version uses message exchanges for datum synchronization. The `WAIT` call blocks the current task until a message arrives at the exchange. This integrates datum reception into the task scheduling system.

---

### FGET (HSVCM.S) - Get Datum from Host (Mini-100)

**Calling convention**: Same as HSVC.S version

**Algorithm**:
1. Validate source slot (1-7 only)
2. Poll VDATM slot directly in busy-wait loop
3. When value non-zero found, enter critical section
4. Read and clear datum value
5. Shift right 3 bits
6. Re-enable interrupts

**AP side effects**: Same as HSVC.S version, but uses polling instead of message exchanges.

**Cross-references**: None (self-contained).

**Key difference**: The Mini-100 version uses busy-wait polling (`FG200` loop) instead of blocking on a message exchange. This is simpler but wastes CPU cycles. The Mini-100 does not support multi-tasking, so busy-waiting is acceptable.

---

### FTST (HSVC.S and HSVCM.S) - Test if Datum Available

**Calling convention**:
- Input: `R1` = source slot (0=any, 1-7=specific)
- Output: `R2` = flag (0=found, +1=invalid slot, -1=not found), `R3` = datum value

**Algorithm**:
1. If R1=0, search all 7 slots for first non-zero value
2. If R1=1-7, check only that slot
3. If value found, jump to FDATUM to read and clear
4. If not found, return with flag=-1

**AP side effects**:
- Reads: VDATM slots
- Writes: VDATM slot (cleared if value found)
- SPAD: R0-R4 modified
- DPX: X0-X3 used

**Cross-references**: Used by application tasks to poll for host data without blocking.

**Super-100 vs Mini-100 difference**: The Super-100 version (HSVC.S) uses `TWAIT` external for timed wait on message exchanges. The Mini-100 version (HSVCM.S) uses simple memory polling with `NOP` for timing.

---

## 4. Architectural Insights

### 4.1 Interrupt Architecture

The `$ISR 7` directive in HIRP.S and HIRPM.S reveals that the FPS-100 supervisor uses **IRQ level 7** for host communication. This is the highest priority interrupt level, indicating host communication is time-critical. The interrupt handler:
- Re-enables interrupts early (`ION` at entry) to allow nesting
- Clears R0 before return to re-enable the specific host IRP
- Uses `IOFF`/`ION` pairs for critical section protection

### 4.2 Host-AP Communication Protocol

The code reveals a sophisticated bidirectional protocol:

**Host to AP** (via SWR):
1. Host writes SWR, setting APSTAT3 bit 4000
2. AP detects interrupt (IRQ7) or polls APSTAT3
3. AP reads SWR via `SWDB` instruction
4. AP processes the command/datum
5. AP clears R0 on return to re-enable host IRP

**AP to Host** (via LITES):
1. AP waits for host to read previous LITES (APSTAT3 bit 2000 clear)
2. AP writes LITES via `DBLLIT` instruction
3. AP sets CTRL bit 5 via `INTEN` to interrupt host
4. Host reads LITES and processes

### 4.3 Message-Passing Model (Super-100)

The Super-100 implements a sophisticated message-passing system:

- **Message buffers** (APMSG, MGDAT1-7): Contain the actual message data with queue links
- **Message exchanges** (EXAPEX, EXFUNC, EXDAT1-7): Queue headers where tasks wait for messages
- **Answer keys**: Each message contains the exchange address where the reply should be sent

This is a **rendezvous-style** message system where:
- Sender places message on exchange's queue
- Receiver waits on exchange (via `WAIT` or `TWAIT`)
- Messages are self-contained with queue links for efficient insertion/deletion

### 4.4 Datum Exchange Protocol

The datum system provides 7 numbered slots for real-time data exchange:

- **16-bit word format**: Bits 15-13 = slot number (3 bits), Bits 12-0 = data (13 bits)
- **Synchronization**: Super-100 uses message exchanges; Mini-100 uses direct memory polling
- **Atomic access**: Critical sections with `IOFF`/`ION` ensure datum read-and-clear is atomic

### 4.5 Configuration Table

The `/CONFIG/` table in IOQUE.S reveals the FPS-100's I/O device model:

- 15 device slots (matching the 15-bit IMASK register)
- Each entry: priority mask, bit mask, service routine pointer, device address, IMASK save area
- The overlay map (`/ISRMAP/`) allows service routines to be swapped in/out of TM

### 4.6 Memory Architecture

The code reveals how the FPS-100 supervisor uses Main Data memory:

- **Queue nodes**: 2 words (RLINK, LLINK) - used for all linked lists
- **Message buffers**: Variable length (11 words for APMSG, 7 for MGDAT)
- **Message exchanges**: 6 words (queue header + type/length/misc)
- **Configuration table**: 75 words (15 devices × 5 words)
- **Datum storage**: 7 words (Mini-100) or 21 words (Super-100, includes buffer/exchange pointers)

### 4.7 Task Model Differences

The code reveals fundamental differences between Super-100 and Mini-100:

| Feature | Super-100 (MTS100) | Mini-100 (RTS100) |
|---------|-------------------|-------------------|
| Task types | APEX, FUNC interpreter | None (datum only) |
| Synchronization | Message exchanges with WAIT/TWAIT | Busy-wait polling |
| Datum storage | 21 words (values + buffers + exchanges) | 7 words (values only) |
| Code size | Larger (326 + 209 lines) | Smaller (96 + 200 lines) |
| Complexity | Full multi-tasking | Simple real-time |

---

## 5. Design Observations

### 5.1 Performance Optimization Patterns

**Cycle-counted operations**: The queue routines document exact cycle counts (11 for INSERT, 5 for EMPTY, 7 for DELETE). This reflects the FPS-100's real-time requirements where every cycle matters.

**Memory timing management**: The code uses `NOP` instructions (HSVCM.S `TWATE` loop) and `STATMA` double-reads (IOQUE.S) to ensure memory cycles complete before using results. The AP-120B's MD has a 2-cycle access time, requiring careful timing.

**Register reuse**: SPAD registers are aggressively reused. For example, in `INSERT`, SP0 is used for comparison, then for error code, then for SPFN. This minimizes register save/restore overhead.

**Parallel operations**: The code interleaves memory operations with arithmetic. For example:
```apal
LDSPI NEW; DB=DPX(3);          "Load address while setting up
LDMA                             "Start memory read
LDSPI NEXT; DB=DPX(2); LDMA    "Next address while memory cycles
```

### 5.2 Error Handling Patterns

**Return codes in SPFN**: All routines use SPAD0 and SPFN for error returns. SPFN is the "function value" register that the supervisor uses for return status.

**Self-link checking**: The `INSERT` routine verifies a node is unlinked by checking RLINK points to itself. This is a common FPS-100 idiom for "node not in any queue."

**Graceful degradation**: `ENABLE` returns mask=0 if device not found, allowing callers to handle missing devices. `FGET` returns flag=-1 for slot 0, flag=+1 for invalid slots.

### 5.3 Code Organization Patterns

**Dual-mode implementation**: The Super-100 and Mini-100 versions share the same entry points and calling conventions but have different implementations. This allows the same application code to run on either supervisor.

**Common data via $COMMON**: The `/FHOSTC/` common block is used by both HIRP.S and HSVC.S (and their Mini-100 counterparts) to share VDATM data. This is the FPS-100 equivalent of global variables.

**Configuration via $INSERT**: System definitions (`SYSDEF`, `MINDEF`) and host communication constants (`FHOSTC`) are included via `$INSERT`. This modularizes the code and allows configuration changes without modifying source.

### 5.4 Hardware Interface Patterns

**APSTAT3 polling**: The code polls APSTAT3 bits rather than using interrupts for host synchronization. This is simpler but wastes cycles. The comment "THIS ASSUMES SUPERVISOR MODE AND INTERRUPTS OFF" in IOQUE.S confirms these routines run at high priority.

**SWDB instruction**: The `SWDB` instruction reads the SWR directly to the Data Bus. This is a special I/O operation that also clears the SWR-written flag in APSTAT3, completing the handshake.

**DBLLIT instruction**: Writing to LITES via `DBLLIT` is the AP-to-host communication mechanism. The `INTEN` instruction then generates the host interrupt.

### 5.5 Resource Management Patterns

**Fixed-size tables**: All data structures have fixed maximum sizes (15 devices, 7 datum slots, 8 SPAD registers). This simplifies memory management but limits scalability.

**Static allocation**: All buffers and exchanges are statically allocated via `$DATA` directives. There is no dynamic memory allocation in this subsystem.

**Overlay support**: The `/ISRMAP/` table in `ENABLE` contains pointers to service routines in an overlay map. This suggests the FPS-100 supervisor can swap code in/out of Table Memory.

### 5.6 Historical Context

The code reflects 1979-era embedded systems design:

- **Assembly language**: All code is in APAL; no higher-level language support
- **Fixed-point arithmetic**: No floating-point in the communication layer
- **Manual timing**: Programmers explicitly manage memory access timing
- **Global variables**: Common blocks used extensively
- **Simple synchronization**: Polling and interrupt disable/enable for mutual exclusion
- **Code duplication**: Super-100 and Mini-100 versions share significant code

The dual-mode design (MTS100 vs RTS100) shows FPS-100's market strategy: a full-featured supervisor for complex applications and a lightweight version for real-time control. The datum exchange mechanism (7 slots) is a precursor to modern mailbox/IPC mechanisms.

---

## Summary

The `kernel_io` subsystem provides the AP-side communication infrastructure for the FPS-100 supervisor, supporting both the full Super-100 (MTS100) and lightweight Mini-100 (RTS100) environments. It implements:

1. **Efficient doubly-linked queue operations** (7-11 cycles) for I/O and task management
2. **Interrupt-driven host communication** via IRQ7, using SWR and LITES registers
3. **Message-passing system** (Super-100) with exchanges and rendezvous synchronization
4. **Datum exchange protocol** with 7 numbered slots for real-time data
5. **Device configuration** via table lookup for interrupt mask mapping

The code reveals the FPS-100's sophisticated interrupt architecture, memory-timing requirements, and the fundamental differences between the Super-100 and Mini-100 supervisor models. The design emphasizes minimal latency, deterministic timing, and efficient use of the AP's limited register set.

### GLM final

(adv 120s, 11578c)

# Structured Analysis: AP-Side Supervisor I/O Queue & Host-RPC Subsystem

## 1. Subsystem Overview

This group of files implements the **host communication and I/O queue management layer** of the FPS-100's AP-side supervisor (Super-100/Mini-100). It provides:

- **Doubly-linked queue primitives** for I/O driver management
- **Host interrupt service routines** that process incoming messages
- **Host communication services** for datum value transfer and message passing
- **Two variants**: MTS100 (full message-passing) and RTS100 (simplified datum-only)

The subsystem bridges the host computer and AP-resident tasks through interrupt-driven communication with handshake synchronization.

---

## 2. Per-File Purpose

### IOQUE.S — I/O Driver Queue Support Routines

| Attribute | Value |
|-----------|-------|
| **$TITLE** | INSERT, EMPTY, DELETE, ENABLE |
| **$ENTRY** | INSERT,0; EMPTY,0; DELETE,0; ENABLE |
| **$EXT** | None |
| **$COMMON** | /CONFIG/ (DEV1-DEV15, each 5 words); /ISRMAP/ (120 words) |

**Purpose**: Implements fundamental doubly-linked list operations for I/O driver management, plus an interrupt enable routine.

**AP State Manipulated**:
- **DPX(2), DPX(3)**: Queue element addresses
- **SPAD 0-3**: Scratch registers, error codes
- **MD**: Queue link fields (RLINK, LLINK)
- **APSTAT3**: Polling for interrupt status (in ENABLE)

---

### HIRP.S — Host Interrupt Service Routine (MTS100)

| Attribute | Value |
|-----------|-------|
| **$TITLE** | HIRP |
| **$ENTRY** | HIRP,0 |
| **$EXT** | SEND, WATSWR |
| **$ISR** | 7 |
| **$INSERT** | SYSDEF, FHOSTC |

**Purpose**: Full-featured host interrupt handler for MTS100. Processes messages, dispatches to APEX tasks, FUNC interpreter, or handles SPLDGO.

**AP State Manipulated**:
- **SWR**: Read via SWDB for host data
- **APSTAT3**: Polled for synchronization
- **DPX(X0-X3)**: Message buffers, datum values
- **SPAD R0-R7**: Parameters, scratch
- **MD**: Message buffers, exchange areas, VDATM storage
- **Interrupt system**: ION/IOFF, INTEN for host IRP

---

### HSVC.S — Host Communication Services (MTS100)

| Attribute | Value |
|-----------|-------|
| **$TITLE** | HSVC |
| **$ENTRY** | WATSWR, SENDER, FPUT, FGET, FTST |
| **$EXT** | WAIT, TWAIT |
| **$INSERT** | SYSDEF, FHOSTC |

**Purpose**: Host communication primitives for MTS100: synchronization, message sending, and datum transfer.

**AP State Manipulated**:
- **APSTAT3**: Polled for SWR/LITES flags
- **DBLLIT**: Write to host LITES register
- **DPX(X0-X3)**: Message arguments
- **SPAD R0-R7**: Parameters, scratch
- **MD**: VDATM storage, exchange addresses
- **Interrupt system**: ION/IOFF, INTEN

---

### HIRPM.S — Host Interrupt Service Routine (RTS100)

| Attribute | Value |
|-----------|-------|
| **$TITLE** | HIRP |
| **$ENTRY** | HIRP,0 |
| **$EXT** | WATSWR |
| **$ISR** | 7 |
| **$INSERT** | MINDEF |

**Purpose**: Simplified host interrupt handler for RTS100. Only handles datum value updates (no task dispatching).

**AP State Manipulated**:
- **SWR**: Read via SWDB
- **DPX(X1)**: Datum value
- **SPAD R0-R3**: Scratch
- **MD**: VDATM(1-7) storage
- **Interrupt system**: ION/IOFF

---

### HSVCM.S — Host Communication Services (RTS100)

| Attribute | Value |
|-----------|-------|
| **$TITLE** | HSVC |
| **$ENTRY** | WATSWR, SENDER, FPUT, FGET, FTST, WATLIT |
| **$EXT** | None |
| **$INSERT** | MINDEF |

**Purpose**: Simplified host communication for RTS100. Same primitives as HSVC.S but uses polling instead of external WAIT/TWAIT.

**AP State Manipulated**:
- **APSTAT3**: Polled for SWR/LITES flags
- **DBLLIT**: Write to host LITES
- **DPX(X0-X3)**: Message arguments
- **SPAD R0-R4**: Parameters, scratch
- **MD**: VDATM(1-7) storage
- **Interrupt system**: ION/IOFF, INTEN

---

## 3. Key Routines

### INSERT (IOQUE.S)
```
Calling Convention:
  (IN)  DPX(2) = Address of NEXT element
  (IN)  DPX(3) = Address of NEW element to insert
  (OUT) SPAD 0, SPFN = 0 (success) or non-zero (error)

Side Effects:
  - Verifies NEW is unlinked (points to itself)
  - Updates 4 link fields: LLINK(NEXT), RLINK(NEW), LLINK(NEW), RLINK(LAST)
  - SPAD 0-3, DPX 2-3 modified

Cross-references: None in this group; used by I/O driver framework
```

### EMPTY (IOQUE.S)
```
Calling Convention:
  (IN)  DPX(2) = Address of queue header or element
  (OUT) DPX(3) = Address of NEXT element
  (OUT) SPAD 0, SPFN = 0 if empty

Side Effects:
  - Compares RLINK(LAST) to itself to determine if queue is empty
  - SPAD 0-1, DPX 2-3 modified
```

### DELETE (IOQUE.S)
```
Calling Convention:
  (IN)  DPX(3) = Address of element to delete
  (OUT) DPX(2) = Address of deleted element's successor

Side Effects:
  - Reads RLINK/LLINK of element
  - Updates 4 link fields to remove element
  - Self-links the deleted element (marks as unlinked)
  - SPAD 1-3, DPX 2-3 modified
```

### ENABLE (IOQUE.S)
```
Calling Convention:
  (IN)  R0 = Device address
  (OUT) R4 = Bit mask for interrupt enable (0 if not found)

Side Effects:
  - Searches /CONFIG/ table (15 devices, 5 words each)
  - Returns interrupt mask corresponding to device address
  - SPAD R0-R4 modified
```

### HIRP (HIRP.S)
```
Calling Convention:
  Called by hardware on host interrupt (ISR 7)
  (IN)  SWR contains first word from host
  (OUT) R0 cleared to re-enable host IRP

Side Effects:
  - Reads SWR and dispatches based on message type:
    - Option 1 (SPLDGO): Reads SPAD values into FSPAD
    - Option 2 (RUNAP): Sends message to APEX task
    - Option 3 (FUNC): Sends message to FUNC interpreter
    - Datum (bit 0 set): Stores in VDATM
  - Uses SEND for message delivery
  - ION at entry, IOFF during critical sections

Cross-references: HIRPM.S (simplified variant), HSVC.S (WATSWR)
```

### APXMT (HIRP.S/HIRPM.S)
```
Calling Convention:
  (OUT) R1 = 16-bit value from SWR
  (OUT) DPX(X1) = same value

Side Effects:
  - Calls WATSWR to wait for host write
  - Executes SWDB to read SWR
  - Preserves R3-R7

Cross-references: WATSWR (local)
```

### DATUM (HIRP.S)
```
Calling Convention:
  (IN)  R0, R1 = Datum value from host
  (IN)  DPX(X1) = Datum value

Side Effects:
  - Extracts 3-bit index from R0
  - Stores datum in VDATM[index]
  - If old value was zero, sends message via SEND
  - IOFF during critical section
```

### WATSWR (HSVC.S/HSVCM.S)
```
Calling Convention:
  Waits for host to write SWR

Side Effects:
  - Polls APSTAT3 bit 4000 (SWR flag) via INBS
  - SPAD R0-R1 modified
```

### SENDER (HSVC.S/HSVCM.S)
```
Calling Convention:
  (IN)  DPX(X0) = First message word
  (IN)  DPX(X1) = Second word (if needed)
  (IN)  DPX(X2) = Third word (if needed)

Side Effects:
  - Calls WATLIT to synchronize
  - Writes to host LITES via DBLLIT
  - Issues INTEN to trigger host IRP
  - Sends 1-3 words based on first word value
  - IOFF during critical section
```

### FPUT (HSVC.S/HSVCM.S)
```
Calling Convention:
  (IN)  R1 = Destination (1-7)
  (IN)  R2 = Datum value

Side Effects:
  - Masks R1 to 3 bits
  - Shifts R2 left by 3 bits and ORs with destination
  - Calls SENDER to send to host
  - Returns immediately if destination = 0
```

### FGET (HSVC.S/HSVCM.S)
```
Calling Convention:
  (IN)  R1 = Source selector (1-7)
  (OUT) R2 = Flag: 0=success, +1=error, -1=SORS=0
  (OUT) R3 = Datum value (if flag=0)

Side Effects:
  - Uses WAIT/TWAIT (MTS) or busy-wait (RTS) for blocking
  - Critical section: reads and clears datum atomically
  - Shifts result right by 3 bits to remove index
```

### FTST (HSVC.S/HSVCM.S)
```
Calling Convention:
  (IN)  R1 = Source selector (0=all, 1-7=specific)
  (OUT) R2 = Flag: 0=found, +1=error, -1=not found
  (OUT) R3 = Datum value (if flag=0)

Side Effects:
  - Scans all slots or checks specific one
  - Uses TWAIT (MTS) or polling (RTS)
  - Falls through to FDATUM for read-and-clear
```

### HIRP (HIRPM.S)
```
Calling Convention:
  Called by hardware on host interrupt (ISR 7)
  (IN)  SWR contains datum value from host
  (OUT) R0 cleared to re-enable host IRP

Side Effects:
  - Reads SWR and stores datum in VDATM[index]
  - IOFF during store
  - No message dispatching (simplified variant)
```

---

## 4. Architectural Insights

### Interrupt Management
- Host interrupts use **level 7** (highest priority)
- Handler immediately enables interrupts (`ION`) for nested handling
- Return convention: **clear R0** to re-enable host IRP
- Critical sections protected with `IOFF`/`ION`

### Host Communication Protocol
- **Three-phase handshake**: 
  1. Host writes SWR → AP sees bit 4000 clear
  2. AP reads SWR and processes
  3. AP writes LITES → host sees bit 2000 clear
  4. AP issues INTEN → host receives interrupt
- **Message format**: First word indicates message type and length
- **Datum format**: 16 bits with 3-bit index (1-7) + 13-bit value

### Supervisor Variants
- **MTS100**: Full supervisor with task dispatching (APEX/FUNC messages)
- **RTS100**: Simplified with only datum communication
- Message-passing vs datum-only reveals two different operational modes

### Data Structures
- **Doubly-linked queues** for I/O management with self-linking unlinked elements
- **Message buffers** with RLINK/LLINK links (APMSG, MGDAT1-7)
- **Exchange areas** for message queuing (EXAPEX, EXFUNC, EXDAT1-7)
- **VDATM array** for datum storage with offset calculations for values and exchanges

### Synchronization Primitives
- **APSTAT3 polling** for host communication flags
- **Memory timing** managed with STATMA and NOP instructions
- **Atomic operations** in critical sections (FGET/FTST read-and-clear)

---

## 5. Design Observations

### Performance Optimizations
- **Minimal cycle counts**: INSERT documented as 11 cycles success, 7 failure
- **Instruction pairing**: Columnar format enables parallel execution
- **Self-linking for unlinked state**: O(1) check if queue element is linked
- **Register reuse**: SPAD/DPX registers reused aggressively to minimize memory traffic

### Coding Patterns
- **Columnar format**: Labels in column 1, opcodes in column 2, operands in column 3
- **Symbolic naming**: R0-R7, X0-X3 defined via $EQU in system headers
- **Error handling**: SPAD 0 and SPFN both set for redundant error indication
- **Common blocks**: /CONFIG/ and /FHOSTC/ for shared data structures

### Memory Layout Strategy
- **Inline data structures**: Message buffers defined as $DATA immediately after declaration
- **Offset calculations**: VDATM organized with values at base, message buffers at +7, exchanges at +14
- **Configuration table order**: /CONFIG/ entries match IMASK bit positions
- **Overlay management**: ENABLE references /ISRMAP/ for service routine overlay loading

### Communication Design
- **Two-mode operation**: Blocking (MTS) vs polling (RTS) for datum retrieval
- **Message diversity**: Supports both single-word datums and multi-word task messages
- **Interrupt-driven**: Host IRP triggered by INTEN instruction
- **Handshake synchronization**: LITES register for explicit host acknowledgment

### Architectural Reveals
- **Supervisor task model**: APEX user tasks and FUNC interpreter task running in supervisor mode
- **I/O device model**: Up to 15 devices with priority masks and service routine pointers
- **Memory-mapped registers**: SWR and LITES for host-AP communication
- **Interrupt hierarchy**: Host interrupt at level 7 with nested interrupt capability

This code reveals a sophisticated host-AP communication subsystem with carefully designed protocols for both full message-passing (MTS100) and simplified datum exchange (RTS100), demonstrating the FPS engineers' understanding of real-time embedded system requirements in 1979.

<details><summary>Cooperative drafts</summary>

#### DS coop

# Structured Analysis: AP-Side Supervisor I/O Queue & Host-RPC Subsystem

## 1. Subsystem Overview

This group of files implements the **host communication and I/O queue management layer** of the FPS-100's AP-side supervisor (Super-100/Mini-100). It provides:

- **Doubly-linked queue primitives** (INSERT, DELETE, EMPTY) used by the supervisor's I/O driver framework
- **Host interrupt service routines** that handle incoming messages from the host computer
- **Host communication services** for sending/receiving messages and datum values
- **Two variants**: one for MTS100 (full message-passing with APEX/FUNC tasks) and one for RTS100 (simplified datum-only communication)

The subsystem bridges the host computer and AP-resident tasks (APEX user tasks, FUNC interpreter tasks) through a message exchange mechanism.

---

## 2. Per-File Purpose

### IOQUE.S — I/O Driver Queue Support Routines

| Attribute | Value |
|-----------|-------|
| **$TITLE** | INSERT, EMPTY, DELETE, ENABLE |
| **$ENTRY** | INSERT,0; EMPTY,0; DELETE,0; ENABLE |
| **$EXT** | None |
| **$COMMON** | /CONFIG/ (DEV1-DEV15, each 5 words); /ISRMAP/ (120 words) |

**Purpose**: Provides fundamental doubly-linked list queue operations for I/O driver management, plus an interrupt enable routine that searches a device configuration table.

**AP State Manipulated**:
- **DPX(2), DPX(3)**: Parameters (addresses of queue elements)
- **SPAD 0-3**: Scratch registers, error codes
- **MD**: Queue link fields (RLINK, LLINK)
- **APSTAT3**: Read via INBS for interrupt status polling (in ENABLE context)

---

### HIRP.S — Host Interrupt Service Routine (MTS100 variant)

| Attribute | Value |
|-----------|-------|
| **$TITLE** | HIRP |
| **$ENTRY** | HIRP,0 |
| **$EXT** | SEND, WATSWR |
| **$ISR** | 7 (interrupt level 7) |
| **$INSERT** | SYSDEF, FHOSTC |

**Purpose**: Full-featured host interrupt handler for MTS100. Receives host messages, dispatches to APEX tasks, FUNC interpreter tasks, or handles SPLDGO (SPAD load) and datum value updates.

**AP State Manipulated**:
- **SWR** (Status Word Register): Read via SWDB instruction for host data
- **APSTAT3**: Polled via INBS for synchronization
- **DPX(X0-X3)**: Message buffer addresses, datum values
- **SPAD R0-R7**: Parameter passing, scratch
- **MD**: Message buffers (APMSG, MGDAT1-7), exchanges (EXAPEX, EXFUNC, EXDAT1-7), datum storage (VDATM)
- **Interrupt system**: ION/IOFF for interrupt control, INTEN for host IRP

---

### HSVC.S — Host Communication Services (MTS100 variant)

| Attribute | Value |
|-----------|-------|
| **$TITLE** | HSVC |
| **$ENTRY** | WATSWR, SENDER, FPUT, FGET, FTST |
| **$EXT** | WAIT, TWAIT |
| **$INSERT** | SYSDEF, FHOSTC |

**Purpose**: Provides host communication primitives for MTS100: waiting for host synchronization flags, sending messages to host, and datum value transfer (FPUT/FGET/FTST).

**AP State Manipulated**:
- **APSTAT3**: Polled for SWR/LITES flags
- **DBLLIT**: Instruction to write to host LITES register
- **DPX(X0-X3)**: Message arguments
- **SPAD R0-R7**: Parameters and scratch
- **MD**: VDATM storage, exchange addresses
- **Interrupt system**: ION/IOFF, INTEN for host IRP

---

### HIRPM.S — Host Interrupt Service Routine (RTS100 variant)

| Attribute | Value |
|-----------|-------|
| **$TITLE** | HIRP |
| **$ENTRY** | HIRP,0 |
| **$EXT** | WATSWR |
| **$ISR** | 7 |
| **$INSERT** | MINDEF |

**Purpose**: Simplified host interrupt handler for RTS100. Only handles datum value updates (no APEX/FUNC message dispatching).

**AP State Manipulated**:
- **SWR**: Read via SWDB
- **DPX(X1)**: Datum value
- **SPAD R0-R3**: Scratch
- **MD**: VDATM(1-7) storage
- **Interrupt system**: ION/IOFF

---

### HSVCM.S — Host Communication Services (RTS100 variant)

| Attribute | Value |
|-----------|-------|
| **$TITLE** | HSVC |
| **$ENTRY** | WATSWR, SENDER, FPUT, FGET, FTST, WATLIT |
| **$EXT** | None |
| **$INSERT** | MINDEF |

**Purpose**: Simplified host communication for RTS100. Same primitives as HSVC.S but without external WAIT/TWAIT dependencies — uses busy-wait polling instead.

**AP State Manipulated**:
- **APSTAT3**: Polled for SWR/LITES flags
- **DBLLIT**: Write to host LITES
- **DPX(X0-X3)**: Message arguments
- **SPAD R0-R4**: Parameters and scratch
- **MD**: VDATM(1-7) storage
- **Interrupt system**: ION/IOFF, INTEN

---

## 3. Key Routines

### IOQUE.S Routines

#### INSERT
```
Calling Convention:
  (IN)  DPX(2) = Address of NEXT element
  (IN)  DPX(3) = Address of NEW element to insert
  (OUT) SPAD 0, SPFN = 0 (success) or non-zero (error: NEW already linked)

Side Effects:
  - Reads RLINK(NEW) to verify it points to self (unlinked)
  - Writes LLINK(NEXT) = NEW
  - Writes RLINK(NEW) = NEXT
  - Writes LLINK(NEW) = LAST (from LLINK(NEXT))
  - Writes RLINK(LAST) = NEW
  - SPAD 0-3, DPX 2-3 modified

Cross-references: None in this group; used by I/O driver framework
```

#### EMPTY
```
Calling Convention:
  (IN)  DPX(2) = Address of queue header or element (LAST)
  (OUT) DPX(3) = Address of NEXT element
  (OUT) SPAD 0, SPFN = 0 if empty (no successor), non-zero otherwise

Side Effects:
  - Reads RLINK(LAST) to get NEXT
  - SPAD 0-1, DPX 2-3 modified

Cross-references: None in this group
```

#### DELETE
```
Calling Convention:
  (IN)  DPX(3) = Address of element to delete
  (OUT) DPX(2) = Address of deleted element's successor

Side Effects:
  - Reads RLINK(OUT) and LLINK(OUT)
  - Writes LLINK(OUT) = OUT (self-link, marks as unlinked)
  - Writes LLINK(NEXT) = LAST
  - Writes RLINK(LAST) = NEXT
  - Writes RLINK(OUT) = OUT (self-link)
  - SPAD 1-3, DPX 2-3 modified

Cross-references: None in this group
```

#### ENABLE
```
Calling Convention:
  (IN)  R0 = Device address
  (OUT) R4 = Bit mask for interrupt enable (0 if not found)

Side Effects:
  - Searches /CONFIG/ table (DEV1-DEV15, 5 words each)
  - Reads device addresses and bit masks from configuration table
  - SPAD R0-R4 modified

Cross-references: /CONFIG/ common block, /ISRMAP/ common block
```

### HIRP.S Routines

#### HIRP (Main Interrupt Handler)
```
Calling Convention:
  Called by hardware on host interrupt (ISR 7)
  (IN)  SWR contains first word from host
  (OUT) R0 cleared to re-enable host IRP

Side Effects:
  - Reads SWR via APXMT subroutine
  - Dispatches based on option value:
    - Option 1 (SPLDGO): Reads SPAD values from host into FSPAD
    - Option 2 (RUNAP): Sends message to APEX task
    - Option 3 (FUNC): Sends message to FUNC interpreter task
    - Datum (bit 0 set): Stores datum value in VDATM
  - Uses SEND (external) for message delivery
  - Modifies APMSG buffer contents
  - ION at entry, IOFF during critical sections

Cross-references: HIRPM.S (simplified variant), HSVC.S (WATSWR), SEND (external)
```

#### APXMT (Get Value from Host)
```
Calling Convention:
  (OUT) R1 = 16-bit value from SWR
  (OUT) DPX(X1) = same value

Side Effects:
  - Calls WATSWR to wait for host to write SWR
  - Executes SWDB instruction to read SWR
  - Preserves R3-R7

Cross-references: HSVC.S (WATSWR), HIRPM.S (same routine)
```

#### DATUM (Process Datum Value)
```
Calling Convention:
  (IN)  R0, R1 = Datum value from host
  (IN)  DPX(X1) = Datum value

Side Effects:
  - Extracts 3-bit index from R0
  - Stores datum value in VDATM[index]
  - If old value was zero, sends message via SEND
  - Uses MGDAT and EXDAT structures for message/exchange
  - IOFF during critical section

Cross-references: HSVC.S (SEND), VDATM storage
```

### HSVC.S Routines

#### WATSWR (Wait for Host to Write SWR)
```
Calling Convention:
  (OUT) Returns when host has written SWR

Side Effects:
  - Polls APSTAT3 bit 4000 (SWR flag) via INBS instruction
  - SPAD R0-R1 modified

Cross-references: HIRP.S, HIRPM.S, HSVCM.S
```

#### WATLIT (Wait for Host to Read LITES)
```
Calling Convention:
  (OUT) Returns when host has read LITES

Side Effects:
  - Polls APSTAT3 bit 2000 (LITES flag) via INBS instruction
  - SPAD R0-R1 modified

Cross-references: HSVCM.S
```

#### SENDER (Send Message to Host)
```
Calling Convention:
  (IN)  DPX(X0) = First message word
  (IN)  DPX(X1) = Second message word (if needed)
  (IN)  DPX(X2) = Third message word (if needed)

Side Effects:
  - Calls WATLIT to synchronize
  - Writes DPX(X0) to LITES via DBLLIT instruction
  - Issues INTEN to IRP host (control bit 5)
  - If first word non-zero (datum), sends only one word
  - If first word zero, sends three words (APEX value, error flag)
  - IOFF during critical section, ION on return

Cross-references: HSVC.S (WATLIT), HSVCM.S
```

#### FPUT (Send Datum to Host)
```
Calling Convention:
  (IN)  R1 = Destination (3 bits, 1-7)
  (IN)  R2 = Datum value (13 bits)

Side Effects:
  - Masks R1 to 3 bits
  - Shifts R2 left by 3 bits
  - ORs destination into datum
  - Stores in DPX(X0) and jumps to SENDER
  - Returns immediately if destination = 0

Cross-references: HSVC.S (SENDER)
```

#### FGET (Get Datum from Host)
```
Calling Convention:
  (IN)  R1 = Source selector (SORS)
  (OUT) R2 = Flag: 0=success, +1=error, -1=SORS=0
  (OUT) R3 = Datum value (if flag=0)

Side Effects:
  - Validates SORS range (1-7)
  - Uses WAIT (external) for blocking wait on exchange
  - Critical section: reads and clears datum value atomically
  - Shifts datum right by 3 bits to remove index
  - IOFF during critical section

Cross-references: WAIT (external), TWAIT (external)
```

#### FTST (Test if Datum Available)
```
Calling Convention:
  (IN)  R1 = Source selector (SORS): 0=scan all, 1-7=specific
  (OUT) R2 = Flag: 0=found, +1=error, -1=not available
  (OUT) R3 = Datum value (if flag=0)

Side Effects:
  - If SORS=0, scans all 7 slots for first available
  - If SORS=1-7, checks only that slot
  - Uses TWAIT (external) for timed wait
  - Falls through to FDATUM for read-and-clear

Cross-references: TWAIT (external), FDATUM (local)
```

### HIRPM.S Routines

#### HIRP (Simplified Interrupt Handler)
```
Calling Convention:
  Called by hardware on host interrupt (ISR 7)
  (IN)  SWR contains datum value from host
  (OUT) R0 cleared to re-enable host IRP

Side Effects:
  - Reads SWR via APXMT
  - Extracts 3-bit index
  - Stores datum in VDATM[index]
  - IOFF during store
  - No message dispatching

Cross-references: HSVCM.S (WATSWR)
```

### HSVCM.S Routines

#### FGET (Simplified — Busy-Wait Variant)
```
Calling Convention:
  Same as HSVC.S FGET

Differences from HSVC.S:
  - No external WAIT/TWAIT calls
  - Uses busy-wait loop polling VDATM memory
  - FG200 loop continuously checks for non-zero datum value

Cross-references: None external
```

#### FTST (Simplified — Busy-Wait Variant)
```
Calling Convention:
  Same as HSVC.S FTST

Differences from HSVC.S:
  - No TWAIT external call
  - Uses NOP for memory wait, then checks MD directly
  - Polls memory locations directly

Cross-references: None external
```

---

## 4. Architectural Insights

### Interrupt Dispatch Mechanism
The `$ISR 7` directive in both HIRP.S and HIRPM.S reveals that host interrupts are assigned to **interrupt level 7** (highest priority). The handler:
1. Immediately enables interrupts (`ION`) — allowing nested interrupts
2. Reads SWR to determine message type
3. Dispatches based on option field or datum bit
4. Clears R0 before return to re-enable the host IRP

This "clear R0" convention is a supervisor-level protocol — the return dispatcher checks R0 to decide whether to re-arm the host interrupt.

### Message Exchange Architecture (MTS100)
The MTS100 variant implements a sophisticated **message-passing system** with:
- **Message buffers** (APMSG, MGDAT1-7): Contain link fields, priority, type, length, answer key
- **Message exchanges** (EXAPEX, EXFUNC, EXDAT1-7): Queue headers for pending messages
- **Answer key mechanism**: Each message's word 6 points to an exchange address for replies

This is a **port of the MTS (Michigan Terminal System) message system** to the AP — the exchange/buffer pattern is identical to MTS inter-process communication.

### Datum Value Protocol
The datum mechanism provides **7 numbered slots** (1-7) for lightweight host-AP communication:
- Each datum is 16 bits: 3-bit index + 13-bit value
- The index field identifies which slot (1-7)
- Slots are stored in VDATM array
- A value of 0 in a slot means "no data available"
- The interrupt handler stores new values; consumer tasks read and clear

### Two Supervisor Variants
The existence of both MTS100 and RTS100 variants reveals:
- **MTS100**: Full supervisor with APEX user tasks and FUNC interpreter — requires message queues, SEND/WAIT/TWAIT system calls
- **RTS100**: Reduced supervisor (likely "Real-Time System 100") — datum-only communication, no task dispatching, simpler polling

### Configuration Table Structure
The ENABLE routine's /CONFIG/ table reveals the I/O device model:
- 15 device entries maximum
- Each entry: priority mask, bit mask, service routine pointer, device address, old IMASK save area
- The table order matches IMASK bit positions
- Device addresses are physical (LMAN field)

### Synchronization Primitives
The code reveals AP-level synchronization:
- **APSTAT3 polling**: Bit 4000 = SWR written by host; Bit 2000 = LITES read by host
- **IOFF/ION**: Critical section protection
- **INTEN**: Control bit 5 triggers host interrupt
- **DBLLIT**: Writes to host-visible LITES register

---

## 5. Design Observations

### Performance Tricks

1. **Minimal cycle counts**: INSERT documents "11 cycles if successful, 7 otherwise" — the FPS engineers counted every cycle
2. **Instruction pairing**: APAL's columnar format allows paired operations (e.g., `LDSPI NEW; DB=DPX(3)`) to execute in parallel
3. **Self-link for unlinked state**: Elements point to themselves when not in a queue — allows O(1) check for "already linked"
4. **Memory timing management**: Explicit NOPs and STATMA instructions to wait for memory cycles
5. **Register reuse**: SPAD registers are reused aggressively; DPX registers pass parameters to avoid memory traffic

### Coding Patterns

1. **Columnar format**: Labels in column 1, opcodes in column 2, operands in column 3, comments in column 4
2. **Symbolic register names**: R0-R7, X0-X3 defined via $EQU in SYSDEF/MINDEF
3. **Self-modifying code avoidance**: All data structures are in $DATA sections, not embedded in code
4. **Error return convention**: SPAD 0 and SPFN both set to error code (redundant for reliability)
5. **Queue header as element**: Queue headers are full elements with RLINK/LLINK — EMPTY checks if header points to itself

### Memory Layout Strategy

1. **Common blocks**: /CONFIG/ and /FHOSTC/ for shared data
2. **Data structures inline**: Message buffers and exchanges defined as $DATA immediately after declarations
3. **Offset calculations**: VDATM organized with datum values at base, message buffer pointers at +7, exchange pointers at +14
4. **Overlay map reference**: ENABLE references /ISRMAP/ (120 words) for service routine overlay management

### Error Handling Philosophy

1. **INSERT**: Validates that NEW is unlinked before insertion
2. **ENABLE**: Returns zero mask if device not found (enables nothing)
3. **FGET/FTST**: Returns flag values (-1, 0, +1) rather than trapping
4. **No exception handling**: The code assumes supervisor mode and interrupts off — no protection against misuse

### Host Communication Protocol

The host-AP protocol uses a **three-phase handshake**:
1. Host writes SWR → AP sees bit 4000 clear
2. AP reads SWR → processes data
3. AP writes LITES → host sees bit 2000 clear
4. AP issues INTEN → host receives interrupt

For multi-word messages, this repeats for each word, with the first word (zero) indicating more words follow.

### Variant Differences Summary

| Feature | MTS100 (HIRP.S/HSVC.S) | RTS100 (HIRPM.S/HSVCM.S) |
|---------|------------------------|---------------------------|
| Task dispatching | APEX + FUNC | None |
| Message queues | Full exchange system | Datum only |
| Blocking waits | WAIT/TWAIT (external) | Busy-polling |
| SPAD loading | SPLDGO support | Not supported |
| Configuration | SYSDEF + FHOSTC | MINDEF only |
| Complexity | High | Low |

#### GLM coop

### Structured Analysis of `kernel_io` Subsystem

#### **1. Subsystem Overview**
The `kernel_io` subsystem implements the AP-side communication layer for the **FPS-100/120B supervisor** (Super-100/Mini-100 OS). It manages:
- **I/O Queue Operations**: Thread-safe queue manipulation for task/I/O management.
- **Host-RPC Endpoints**: Bidirectional communication with the host via interrupt-driven RPC and datum exchange.
- **Dual-Mode Support**: Separate implementations for `MTS100` (Multi-Tasking Supervisor) and `RTS100` (Real-Time Supervisor) modes.

#### **2. Per-File Purpose**
##### **IOQUE.S** (I/O Queue Support Routines)
- **`$TITLE`**: `INSERT`, `EMPTY`, `DELETE`, `ENABLE`
- **`$ENTRY`**: `INSERT`, `EMPTY`, `DELETE`, `ENABLE`
- **`$EXT`**: None (uses `$COMMON /CONFIG/` and `$COMMON /ISRMAP/`)
- **Function**:
  - **Queue Management**: Doubly-linked queue insertion/deletion (`INSERT`, `DELETE`) and emptiness checks (`EMPTY`).
  - **Interrupt Enable**: Dynamic I/O device interrupt configuration (`ENABLE`).
- **State Manipulation**:
  - **MD (Main Data)**: Queue links (RLINK/LLINK).
  - **DPX**: Node addresses (DPX(2), DPX(3)).
  - **SPAD**: Error codes (SPAD0, SPFN).

##### **HIRP.S** (Host Interrupt Service – MTS100 Mode)
- **`$TITLE`**: `HIRP`, `SPADS`, `DATUM`, `APXMT`
- **`$ENTRY`**: `HIRP` (interrupt handler)
- **`$EXT`**: `SEND`, `WATSWR`, `$INSERT FHOSTC`
- **Function**:
  - **Host RPC**: Processes host commands (function calls, SPAD loading, datum updates).
  - **Message Dispatch**: Routes requests to APEX/Func tasks via message queues.
- **State Manipulation**:
  - **MD**: Message buffers (APMSG, EXAPEX, EXFUNC, VDATM).
  - **DPX**: Exchange addresses, datum values.
  - **SPAD**: Function parameters (R0-R5).

##### **HSVC.S** (Host Communication – MTS100 Mode)
- **`$TITLE`**: `HSVC`, `WATSWR`, `SENDER`, `FPUT`, `FGET`, `FTST`
- **`$ENTRY`**: `WATSWR`, `SENDER`, `FPUT`, `FGET`, `FTST`
- **`$EXT`**: `WAIT`, `TWAIT`
- **Function**:
  - **Synchronization**: Polls host interface (`WATSWR`, `WATLIT`).
  - **Datum Exchange**: Sends/gets 16-bit datums to/from host slots (1-7).
  - **Host Messaging**: Sends 1-3 word messages (`SENDER`).
- **State Manipulation**:
  - **MD**: VDATM (datum storage).
  - **DPX**: Message words (X0-X2).
  - **APSTAT3**: Host interrupt/status bits.

##### **HIRPM.S** (Host Interrupt Service – RTS100 Mode)
- **`$TITLE`**: `HIRP`, `APXMT`
- **`$ENTRY`**: `HIRP`
- **`$EXT`**: `WATSWR`
- **Function**:
  - **Simplified RPC**: Only handles datum updates (no task messages).
  - **Atomic Updates**: Directly writes to VDATM without messages.
- **State Manipulation**:
  - **MD**: VDATM (datum storage).
  - **DPX**: Datum value (X1).

##### **HSVCM.S** (Host Communication – RTS100 Mode)
- **`$TITLE`**: `HSVC`, `WATSWR`, `SENDER`, `FPUT`, `FGET`, `FTST`, `WATLIT`
- **`$ENTRY`**: `WATSWR`, `SENDER`, `FPUT`, `FGET`, `FTST`, `WATLIT`
- **`$EXT`**: None
- **Function**:
  - **Polling-Based**: Replaces message exchanges with direct VDATM polling (`FGET`/`FTST`).
  - **Optimized Path**: Simplified datum handling for real-time tasks.
- **State Manipulation**:
  - **MD**: VDATM (datum storage).
  - **DPX**: Message words (X0-X2).

#### **3. Key Routines**
##### **INSERT** (IOQUE.S)
- **Convention**:  
  `DPX(2)` = next addr, `DPX(3)` = new addr; `SPAD0/SPFN` = error code.
- **Side Effects**:  
  Updates MD queue links (RLINK/LLINK). Uses SP 0-3, DPX 2-3.
- **Cross-Refs**: Used by task schedulers for queue management.
- **Timing**: 11 cycles (success), 7 cycles (error).

##### **ENABLE** (IOQUE.S)
- **Convention**:  
  `R0` = device addr; returns `R4` = bit mask (0 if not found).
- **Side Effects**:  
  Reads `/CONFIG/` table (15 devices, 5 words/entry). Uses DPX(2)/DPX(3) internally.
- **Cross-Refs**: Initializes interrupt masks for I/O devices.

##### **HIRP** (HIRP.S)
- **Convention**:  
  Interrupt handler; clears `R0` to re-enable host IRP.
- **Side Effects**:  
  Reads SWR, updates VDATM, sends messages to tasks (APEX/FUNC). Modifies SPAD R0-R5, DPX X0-X1.
- **Cross-Refs**: Calls `SEND` (external) and `APXMT`.

##### **APXMT** (HIRP.S/HIRPM.S)
- **Convention**:  
  `R1`/`DPX(X1)` = SWR value.
- **Side Effects**:  
  Polls `APSTAT3` bit 4000. Uses DPX(X1) and SWR.
- **Cross-Refs**: Used by both MTS100 and RTS100 interrupt handlers.

##### **FGET** (HSVC.S/HSVCM.S)
- **Convention**:  
  `R1` = slot (1-7); `R2` = flag (0/-1/+1), `R3` = datum.
- **Side Effects**:  
  **MTS100**: Waits on message exchange; critical section (IOFF/ION).  
  **RTS100**: Polls VDATM directly; shifts datum to remove 3-bit dest.
- **Cross-Refs**: Uses `VDATM` common storage.

#### **4. Architectural Insights**
1. **Interrupt Handling**:  
   Host IRQ7 triggers `HIRP`. The APSTAT3 register (bit 4000) flags SWR writes. Interrupts are disabled (`IOFF`) during critical sections.

2. **Message-Passing Model**:  
   - **MTS100**: Uses message queues (APEX/EXFUNC) for RPC. Messages have 11-word headers (RT/LEFT links, priority, type).  
   - **RTS100**: Bypasses queues for direct VDATM updates (lower latency).

3. **Datum Exchange Protocol**:  
   16-bit values split into 3-bit destination (MSB) and 13-bit data (LSB). Host/AP synchronize via message exchanges (MTS100) or polling (RTS100).

4. **Queue Micro-Operations**:  
   Queues use double-linked nodes (RLINK/LLINK). `INSERT`/`DELETE` are cycle-optimized (7-11 cycles) with minimal scratch usage.

5. **Configuration Flexibility**:  
   `/CONFIG/` table dynamically maps device addresses to interrupt masks, enabling runtime I/O enable/disable.

6. **Memory Architecture**:  
   - **MD (Main Data)**: Holds queues, VDATM, and message buffers.  
   - **TM (Table Memory)**: Implicit in device table lookups (ENABLE).

#### **5. Design Observations**
1. **Idiomatic APAL Patterns**:  
   - Polling (`WATSWR`, `WATLIT`) instead of event-driven I/O (for simplicity).  
   - Fixed-size common areas (`VDATM(7)`) for state.  
   - Critical sections bounded by `IOFF`/`ION` (short, <10 instructions).

2. **Performance Tricks**:  
   - **Register Reuse**: SPAD/DPX registers reused across routines (e.g., `DPX(X0)` for addresses).  
   - **Parallel Fetches**: `LDSPI`/`LDMA` interleaved with arithmetic.  
   - **Bitmask Optimization**: Mask constants (e.g., `DB=7` for datum index) encoded in LDSPI.

3. **Code Duplication**:  
   - MTS100/RTS100 versions share >70% code (HIRP.S ≈ HIRPM.S; HSVC.S ≈ HSVCM.S).  
   - Extracted `$INSERT FHOSTC`/`MINDEF` for common definitions.

4. **Resource Constraints**:  
   - 7-cycle queue ops suggest memory bandwidth is critical.  
   - Interrupts disabled for <1µs (10 cycles @ 10MHz).

5. **Error Handling**:  
   SPAD0/SPFN used for error returns (e.g., `INSERT` checks node validity). No exceptions; all errors recoverable.

6. **Overlay Support**:  
   ENABLE references an overlay map (`/ISRMAP/` word 3) for service routines, enabling code swapping.

--- 

**Summary**: The `kernel_io` subsystem provides a robust, interrupt-driven host communication layer for the FPS-100 supervisor, with dual-mode support for multi-tasking (MTS100) and real-time (RTS100) workloads. Its design emphasizes minimal latency, efficient queue ops, and flexible device configuration. The code reveals tight integration between APSTAT3 (host sync), MD (queues/messages), and polling-based synchronization.

</details>



---

## Group: `rtc`

**Real-Time Clock subsystem**

Files: `RTC.S`, `RTCISR.S`, `RTCREQ.S`, `RTCTST.S`, `RTCDUM.S`, `NORTC.S`

### DeepSeek final

(adv 86s, 21680c)

## Critique of Peer Analysis (GLM)

The peer analysis is **substantially correct** but has several **critical omissions and minor inaccuracies**:

### Strengths
- Correct identification of subsystem role and per-file purposes
- Accurate calling conventions for key routines
- Good architectural insights on interrupt handling and queue management

### Weaknesses

1. **Missing `$ISR` directive significance**: The `$ISR 5.` in RTCISR.S is not just a comment - it's an APAL assembler directive that defines this as interrupt service routine for vector 5. This is crucial for understanding the interrupt dispatch mechanism.

2. **Incorrect external references**: 
   - `RTCINT` is listed as "not in-group" but is actually defined in RTC.S (called from RESTAR)
   - `ENABLE` is listed as from MINCOM but is likely a supervisor routine for device interrupt enabling

3. **Missing critical detail on `RTCCTL`/`RTCCTR`/`RTCCST`**: These are not just "MD registers" - they are specific I/O device addresses (likely in the AP's I/O space, accessed via `LDDA`/`OUT`/`IN` instructions). The peer doesn't explain the I/O addressing mechanism.

4. **Incomplete queue structure analysis**: The peer mentions `RCLOCK`/`ICLOCK` offsets but doesn't explain the complete TCB message format (10 words with specific fields: number, count, links, status, tick count, countdown, repeat, rate, repeat count).

5. **Missing `$COMIO` significance**: In RTCTST.S, `$COMIO TESTC 0` defines a communication I/O region - this is a specific APAL construct for host-AP shared memory, not just a common block.

6. **No analysis of `SPFN` usage**: The constant `SPFN` appears frequently but isn't explained - it's likely a supervisor function number or special register designation.

7. **Incorrect register preservation analysis**: The peer says `DPX(1)` is "temporarily saved" in ADDCLK, but actually `R4` is saved to `DPX(1)` (line 35: `MOV R4,R4;DPX(X1)<SPFN`), not the other way around.

8. **Missing `INBS` significance**: The `INBS` constant used with `IN` instructions is likely "Input Buffer Status" - a special register for reading I/O device status.

9. **No analysis of `STATMA`/`SETMA` timing**: These instructions have specific timing implications (wait states for memory access) that the peer doesn't address.

10. **Missing `$INTEGER` vs `$DATA` distinction**: The peer doesn't explain that `$INTEGER` declares symbolic names while `$DATA` allocates storage - important for understanding the AP's assembly model.

---

## Final Reference Analysis

# RTC Subsystem Analysis: Real-Time Clock for FPS-100/Mini-100 Supervisor

## 1. Subsystem Overview

The RTC subsystem provides **hardware-timer-based task scheduling** for the Mini-100 supervisor running on the FPS-100 array processor. It implements:

- **Priority-ordered timeout queue**: Tasks can request to sleep for specified durations, with the queue sorted by earliest expiration
- **Hardware RTC management**: Programs the AP-120B's real-time clock device (rate, countdown, interrupt generation)
- **Interrupt-driven dispatch**: When a timeout expires, the ISR removes the task from the queue and optionally restarts the clock for the next pending task
- **Host communication interface**: Provides async message passing for timeout requests/responses between host and AP

The subsystem is **optional** - `NORTC.S` provides stubs for systems without RTC hardware.

### Key Architectural Role
The RTC enables **preemptive time-slicing** and **blocking delay operations** in the Mini-100 supervisor, allowing tasks to yield the processor while waiting for time-based events.

---

## 2. Per-File Analysis

### 2.1 RTC.S (275 lines) - Core Queue Management

**Title**: `RESTAR`, `ADDCLK`, `RMVCLK`  
**Entries**: `RESTAR`, `ADDCLK`, `RMVCLK`  
**Externals**: `EMPTY`, `RTCINT`, `RMVCLK` (self-reference), `INSERT`, `DELETE`

**Purpose**: Implements the three fundamental operations on the RTC task queue:
- `RESTAR`: Start/stop the hardware RTC based on queue state
- `ADDCLK`: Insert a task into the time-ordered queue
- `RMVCLK`: Remove a task from the queue

**State Manipulated**:
- **S-Pad (R0-R4)**: Temporary values for queue traversal, arithmetic
- **DPX(X0-X3)**: Task parameters, queue pointers, temporary storage
- **MD (Main Data)**: RTC device registers via `LDDA`/`OUT`/`IN`:
  - `RTCCTL` (I/O address): Control register (run/halt)
  - `RTCCTR` (I/O address): Count register (countdown value)
  - `RTCCST` (I/O address): Status/control register (interrupt clear)
- **TM (Table Memory)**: TCB fields accessed via `LDSPI`/`STATMA`:
  - `RCLOCK`: Forward link offset in TCB
  - `ICLOCK`: Backward link offset in TCB
  - `STATUS`: Task status word offset
  - `CLKBIT`: Bit mask for "in clock queue" status
  - `CRATE`: Clock rate value

**Key Constants**:
- `HALT = 000000`: Instruction to stop RTC
- `RUN = 000441`: Instruction to start RTC (includes rate bits)
- `MASK = 000036`: Rate mask (bits 1-4)
- `MINUS = 177777`: -1 (used for interrupt clear)
- `FIXUP = 000441`: Restart instruction template
- `SPFN`: Supervisor function number (likely 0 or special register)

---

### 2.2 RTCISR.S (101 lines) - Interrupt Service Routine

**Title**: `RTCISR`  
**Entry**: `RTCISR` (via `$ISR 5.` directive - vector 5)  
**Externals**: `INSERT`, `DELETE`

**Purpose**: Handles RTC hardware interrupts. When a timeout expires:
1. Stops the RTC
2. Reads current count from `RTCCTR`
3. Removes the expired task from the request queue (`RTCQ`)
4. If queue not empty, restarts RTC with next task's parameters
5. Returns the expired buffer to the return queue (`RTCRQ`)
6. Updates task status with remaining count

**State Manipulated**:
- **S-Pad (R0-R6)**: Interrupt mask, queue pointers, count values
- **DPX(X2-X3)**: Return queue address, message buffer address
- **MD**: RTC registers, queue headers from `/RTCCOM` common block
- **APSTAT**: Interrupt control via `ION`/`IOFF`
- **TM**: Message buffer fields (tick count, direction, mode, rate)

**Key Data Structures** (from `/RTCCOM`):
- `RTCQ(2)`: Request queue header (forward/backward links)
- `RTCRQ(2)`: Return queue header (forward/backward links)

**Interrupt Handling Sequence**:
1. `ION` - Enable interrupts (allows nesting)
2. Read `RTCQ` head, call `DELETE` to remove first element
3. Stop RTC (`OUT DB=ZERO` to `RTCCTL`)
4. Read current count from `RTCCTR`
5. If queue empty, clear count and jump to DONE
6. Otherwise, fetch next task's parameters (tick count, direction, mode, rate)
7. Build control word: `direction | (mode<<1) | (rate<<2)`
8. Add `RUN` bits (401 octal) and start RTC
9. Set repeat count
10. `IOFF` - Disable interrupts
11. Update message status with current count
12. Insert buffer into return queue
13. Restore R0 and return

---

### 2.3 RTCREQ.S (119 lines) - Request/Answer API

**Title**: `RTCREQ`  
**Entries**: `RTCREQ`, `RTCANS`  
**Externals**: `INSERT`, `ENABLE`, `DELETE`, `EMPTY`

**Purpose**: Provides the programming interface for tasks to:
- `RTCREQ`: Submit a timeout request (async, non-blocking)
- `RTCANS`: Poll for completed timeouts (blocking or non-blocking)

**State Manipulated**:
- **S-Pad (R0-R5)**: Test values, queue pointers, parameter extraction
- **DPX(X0-X3)**: Message addresses, queue headers
- **MD**: RTC registers, return queue (`RTCRQ`)
- **APSTAT**: Interrupt control for atomic queue operations

**RTCREQ Calling Convention**:
- Entry: `DPX(X0)` = message address (buffer with RTC parameters)
- Exit: `R0` = 0 (no errors)
- Side effects: Enqueues message to `RTCQ`; starts RTC if queue was empty

**RTCANS Calling Convention**:
- Entry: `R0` = 0 (non-blocking test), 1 (blocking wait)
- Exit: `R0` = 0 (no buffer), 1 (buffer available); `DPX(3)` = buffer address
- Side effects: Removes buffer from `RTCRQ` return queue

**Key Pattern**: `RTCANS` uses a **busy-wait loop** when `R0=1` (blocking mode), repeatedly calling `EMPTY` to check the return queue. This is a spinlock implementation.

---

### 2.4 RTCTST.S (62 lines) - Test Task

**Title**: `TASK1`  
**Entry**: `TASK1`  
**Externals**: `FPUT`, `FGET`, `RTCANS`, `RTCREQ`

**Purpose**: Test task that exercises the RTC subsystem:
1. Calls `FGET` to get a message from host
2. Sends three timeout requests via `RTCREQ` (with different parameters)
3. Loops waiting for timeouts via `RTCANS`
4. On each timeout, re-queues the message and sends response to host via `FPUT`

**State Manipulated**:
- **S-Pad (R0-R3, R7)**: Message addresses, counts, numbers
- **DPX(X0-X3)**: Message buffer addresses
- **MD**: Message data from `/TESTC` common block
- **TM**: Message fields (count, number)

**Message Format** (10 words):
| Offset | Field | Description |
|--------|-------|-------------|
| 0 | Message number | Identifies which message (1,2,3) |
| 1 | Message count | Number of times sent |
| 2 | RLINK | Forward queue link |
| 3 | LLINK | Backward queue link |
| 4 | STATUS | Message status word |
| 5 | Tick count | RTC countdown value |
| 6 | Count down | Current countdown |
| 7 | Repeat | Repeat flag |
| 8 | Rate | RTC rate code |
| 9 | Repeat count | -1 = infinite repeat |

---

### 2.5 RTCDUM.S (49 lines) - Test Data

**Title**: `RTCDUM`  
**Entries**: None (pure data section)  
**Externals**: None

**Purpose**: Defines three test message buffers (`MSG1`, `MSG2`, `MSG3`) with different RTC parameters:
- `MSG1`: Tick count=100, Rate=12 (fastest)
- `MSG2`: Tick count=100, Rate=11
- `MSG3`: Tick count=50, Rate=12

**Key Detail**: All messages have `Repeat count = -1` (infinite repeat), meaning they will continuously re-queue themselves after each timeout.

---

### 2.6 NORTC.S (40 lines) - No-Hardware Stubs

**Title**: `ADDCLK`, `RMVCLK`  
**Entries**: `ADDCLK`, `RMVCLK`  
**Externals**: None

**Purpose**: Provides do-nothing stubs for systems without RTC hardware. Both routines simply `RETURN` immediately, ignoring all parameters.

**Architectural Significance**: Demonstrates the modular design - the supervisor can be compiled with or without RTC support by selecting the appropriate source files.

---

## 3. Key Routines - Detailed Analysis

### 3.1 RESTAR (RTC.S)

**Calling Convention**:
- Entry: No parameters (uses global `CLKQUE`)
- Exit: Via `RETURN` (no explicit return value)
- Side effect: RTC hardware state changed

**Algorithm**:
```
1. Read CLKQUE head into DPX(X2)
2. Call EMPTY to get first element
3. If queue empty:
   - Write HALT to RTCCTL (stop clock)
   - Write ZERO to RTCCST (clear count)
   - RETURN
4. If queue not empty:
   - Get first element's address
   - Compute delta = ICLOCK - RCLOCK (offset to delta field)
   - Fetch clock rate from CRATE
   - Build RUN instruction with rate bits
   - Read current RTC count from RTCCTR
   - Write new count = current + delta to RTCCST
   - Write RUN|rate to RTCCTL (start clock)
   - If new count <= 0, call RTCINT and RMVCLK
```

**AP State Side Effects**:
- **S-Pad**: R0-R3 modified
- **DPX**: X2 modified (queue head)
- **MD**: RTCCTL, RTCCTR, RTCCST written; CRATE read
- **TM**: TCB delta field accessed via STATMA

**Cross-references**: Calls `EMPTY` (COMSYS), `RTCINT` (RTC.S), `RMVCLK` (RTC.S)

---

### 3.2 ADDCLK (RTC.S)

**Calling Convention**:
- Entry: `DPX(X0)` = wait time, `DPX(X1)` = TCB address
- Exit: Via `RETURN`
- Side effect: Queue modified, possibly RTC restarted

**Algorithm**:
```
1. Save R4 to DPX(1), load R2=time, R3=TCB
2. Read CLKQUE, call EMPTY
3. If queue empty: jump to END (insert and call RESTAR)
4. If queue not empty:
   - Read current RTC count from RTCCTR
   - Loop through queue comparing times:
     - Subtract current delta from requested time
     - If requested <= delta: insert here
     - Otherwise: move to next element, accumulate deltas
   - At insertion point:
     - Adjust delta values
     - Set CLKBIT in task status
     - Store delta in TCB
     - If inserted at head (flag=0): update RTC count and restart
   - Call INSERT to add to queue
   - Restore R4 from DPX(1)
```

**AP State Side Effects**:
- **S-Pad**: R0-R4 modified
- **DPX**: X0-X3 modified (parameters, queue pointers)
- **MD**: RTCCTR, RTCCST, RTCCTL written; CRATE read
- **TM**: TCB status, delta fields modified

**Cross-references**: Calls `EMPTY`, `INSERT` (COMSYS), `RESTAR` (RTC.S)

---

### 3.3 RMVCLK (RTC.S)

**Calling Convention**:
- Entry: `DPX(1)` = TCB address
- Exit: Via `RETURN`
- Side effect: Queue modified, possibly RTC restarted

**Algorithm**:
```
1. Load R2=TCB address, R4=STATUS offset
2. Fetch task status, test CLKBIT
3. If bit not set: RETURN (task not in clock queue)
4. Clear CLKBIT in status, write back
5. Get first element from CLKQUE
6. If TCB is first element:
   - Call DELETE to remove it
   - Call RESTAR to restart RTC
7. If TCB is not first:
   - Get next element
   - If not last: add this delta to next delta (fix up)
   - Call DELETE to remove TCB
```

**AP State Side Effects**:
- **S-Pad**: R0-R4 modified
- **DPX**: X2-X3 modified (queue pointers)
- **TM**: TCB status, delta fields modified

**Cross-references**: Calls `EMPTY`, `DELETE` (COMSYS), `RESTAR` (RTC.S)

---

### 3.4 RTCISR (RTCISR.S)

**Calling Convention**:
- Entry: Hardware interrupt (vector 5), R0 = interrupt bit mask
- Exit: Via `RETURN`, R0 restored, DPX(3) = expired buffer address
- Side effect: Queue modified, RTC restarted

**Algorithm**:
```
1. ION (enable interrupts)
2. Read RTCQ head, call DELETE to remove first element
3. Stop RTC (write ZERO to RTCCTL)
4. Read current count from RTCCTR into R5
5. If queue empty: clear count, jump to DONE
6. If queue not empty:
   - Fetch next task's parameters (tick count, direction, mode, rate)
   - Build control word: (direction) | (mode<<1) | (rate<<2)
   - Add RUN bits (401 octal)
   - Write control to RTCCTL
   - Write repeat count to RTCCST
7. DONE:
   - IOFF (disable interrupts)
   - Update message status with current count (R5)
   - Insert buffer into return queue (RTCRQ)
   - Restore R0 from R6
```

**AP State Side Effects**:
- **S-Pad**: R0-R6 modified
- **DPX**: X2-X3 modified (return queue, buffer address)
- **MD**: RTCCTL, RTCCTR, RTCCST written; RTCQ, RTCRQ modified
- **APSTAT**: ION/IOFF toggled

**Cross-references**: Calls `DELETE`, `INSERT` (COMSYS)

---

### 3.5 RTCREQ (RTCREQ.S)

**Calling Convention**:
- Entry: `DPX(X0)` = message address
- Exit: `R0` = 0 (no errors)
- Side effect: Message enqueued, possibly RTC started

**Algorithm**:
```
1. Load R0=message address, save to DPX(3)
2. Set R4=RTCQ (request queue header), save to DPX(2)
3. IOFF (disable interrupts)
4. Call INSERT to add message to queue
5. ION (enable interrupts)
6. If queue was not empty (R3 != R4): RETURN
7. If queue was empty (R3 == R4):
   - Call ENABLE to get interrupt mask
   - Fetch message parameters (tick count, direction, mode, rate)
   - Build control word and start RTC
   - Set repeat count
   - Enable RTC interrupt in IMASK
```

**AP State Side Effects**:
- **S-Pad**: R0-R5 modified
- **DPX**: X0-X3 modified
- **MD**: RTCCTL, RTCCTR, RTCCST, IMASK written
- **APSTAT**: ION/IOFF toggled

**Cross-references**: Calls `INSERT`, `ENABLE` (supervisor)

---

### 3.6 RTCANS (RTCREQ.S)

**Calling Convention**:
- Entry: `R0` = 0 (non-blocking), 1 (blocking)
- Exit: `R0` = 0 (no buffer), 1 (buffer available); `DPX(3)` = buffer address
- Side effect: Buffer removed from return queue

**Algorithm**:
```
1. Save R0 to R5 (test value)
2. Set R4=RTCRQ (return queue header), save to DPX(2)
3. TEST loop:
   - Call EMPTY to check queue
   - If not empty: jump to FOUND
   - If empty and R5=0: RETURN with R0=0
   - If empty and R5=1: loop back to TEST (busy wait)
4. FOUND:
   - IOFF (disable interrupts)
   - Call DELETE to remove buffer
   - ION (enable interrupts)
   - Set R0=1, RETURN
```

**AP State Side Effects**:
- **S-Pad**: R0, R4, R5 modified
- **DPX**: X2-X3 modified
- **APSTAT**: ION/IOFF toggled

**Cross-references**: Calls `EMPTY`, `DELETE` (COMSYS)

---

## 4. Architectural Insights

### 4.1 Interrupt Handling Architecture

The `$ISR 5.` directive in RTCISR.S reveals the AP-120B's interrupt vectoring mechanism:
- Interrupt vectors are numbered (5 for RTC)
- The assembler generates appropriate entry code
- ISRs can re-enable interrupts (`ION`) for nesting
- Critical sections use `IOFF`/`ION` pairs for atomicity

### 4.2 I/O Device Programming Model

The RTC hardware is accessed via a **memory-mapped I/O** scheme:
- `LDDA` (Load Device Address) sets up the device address
- `OUT` writes to the device, `IN` reads from it
- Device addresses: `RTCCTL` (control), `RTCCTR` (count), `RTCCST` (status)
- `INBS` is used with `IN` to read device status/input buffer

The control word format for `RTCCTL`:
```
Bits 0:    Direction (0=count down, 1=count up)
Bits 1:    Mode (0=one-shot, 1=repeat)
Bits 2-5:  Rate (clock divider)
Bits 8-10: RUN command (401 octal = 100000001 binary)
```

### 4.3 Queue Management Architecture

The RTC uses **doubly-linked circular queues** with:
- Headers in `/RTCCOM` common block (`RTCQ`, `RTCRQ`)
- Links stored at fixed offsets in TCBs/messages (`RCLOCK`, `ICLOCK`)
- Queue operations are atomic (interrupts disabled during modification)
- The `EMPTY` routine tests for empty queue (returns first element or zero)

### 4.4 Task Control Block Structure

TCBs contain at minimum:
- `RCLOCK` offset: Forward link
- `ICLOCK` offset: Backward link  
- `STATUS` offset: Status word with `CLKBIT` for clock queue membership
- Delta field: Time remaining (relative to previous task)

### 4.5 Host Communication Model

The test task (`RTCTST.S`) reveals the host-AP communication mechanism:
- `FGET`/`FPUT`: Host message passing (likely via shared memory or DMA)
- `$COMIO TESTC 0`: Defines a communication I/O region for host-AP data exchange
- Messages are fixed-size buffers (10 words) with specific field layout

### 4.6 Supervisor Services

The RTC subsystem calls several supervisor routines:
- `EMPTY`: Test queue emptiness
- `INSERT`: Add element to queue
- `DELETE`: Remove element from queue
- `ENABLE`: Enable device interrupts
- `RTCINT`: Handle RTC interrupt (called from RESTAR when count expires)

---

## 5. Design Observations

### 5.1 Performance Optimizations

1. **Lazy RTC restart**: `RESTAR` only restarts the hardware RTC when the queue head changes, avoiding unnecessary device programming.

2. **Delta accumulation**: `ADDCLK` accumulates deltas during queue traversal, avoiding the need to recompute absolute times.

3. **Minimal critical sections**: Interrupts are disabled only during actual queue modifications, not during arithmetic or I/O operations.

4. **Register preservation**: `R4` is saved to `DPX(1)` during `ADDCLK` to free a register for queue traversal.

5. **Inline queue operations**: Rather than calling generic queue routines for every operation, the code often manipulates links directly for performance.

### 5.2 Concurrency Patterns

1. **Interrupt-safe queue operations**: All queue modifications in `ADDCLK`, `RMVCLK`, and `RTCISR` are wrapped in `ION`/`IOFF` pairs.

2. **Busy-wait polling**: `RTCANS` uses a spinlock pattern for blocking waits, repeatedly calling `EMPTY` until a buffer appears.

3. **Atomic test-and-set**: `RMVCLK` tests `CLKBIT` before removal, preventing double-removal.

### 5.3 Memory Management

1. **Fixed-size buffers**: Messages are 10 words, allowing efficient allocation and deallocation.

2. **Buffer reuse**: The return queue (`RTCRQ`) recycles expired buffers, avoiding dynamic allocation.

3. **Common blocks**: `/RTCCOM` and `/TESTC` use the `$COMMON` directive for shared data, while `$COMIO` is used for host-AP communication.

### 5.4 Error Handling

1. **Status validation**: `RMVCLK` verifies `CLKBIT` before attempting removal, returning silently if not set.

2. **Queue guards**: `RTCANS` returns `R0=0` for non-blocking mode when no buffer is available.

3. **No explicit error returns**: Most routines return without error codes, relying on side effects and status bits.

### 5.5 Modularity and Testing

1. **Hardware abstraction**: `NORTC.S` provides stubs for systems without RTC, allowing the same supervisor code to run on different hardware configurations.

2. **Test isolation**: `RTCTST.S` and `RTCDUM.S` are separate from the core RTC code, allowing independent testing.

3. **Separation of concerns**: 
   - `RTC.S`: Core queue logic (scheduling)
   - `RTCISR.S`: Interrupt handling (hardware interface)
   - `RTCREQ.S`: API for tasks (programming interface)

### 5.6 APAL Idioms

1. **`LDSPI`/`STATMA` pattern**: Used for indirect memory access through Table Memory:
   ```apal
   LDSPI R0;DB=OFFSET    ; Load offset into R0
   ADD R1,R0;SETMA       ; Add base address, set memory address
   STATMA                ; Wait for memory access
   LDSPI R2;DB=MD        ; Load result into R2
   ```

2. **`MOV R0,R0` as NOP**: Used for timing or to clear condition codes.

3. **`DB=SPFN` pattern**: Writing to supervisor function number, likely triggers a supervisor call or special operation.

4. **`INCMA` for post-increment**: Used to advance through memory fields:
   ```apal
   INCMA                  ; Increment memory address
   LDSPI R1;DB=MD;STATMA ; Fetch next field
   ```

5. **`MI<DB` for conditional store**: Stores value only if minus condition is set (from previous comparison).

### 5.7 Hardware-Specific Patterns

1. **RTC start sequence**: Always: set count first, then write control word with RUN bit.

2. **Interrupt clear sequence**: Write `MINUS` (-1) to `RTCCST`, then read `INBS`.

3. **Rate encoding**: Rate is masked with `MASK=000036` (bits 1-4) and OR'd into the control word.

4. **Device addressing**: `LDDA` sets up device address, then `OUT`/`IN` perform the actual I/O operation.

### GLM final

(adv 111s, 9616c)

### 1. Subsystem Overview
The RTC (Real-Time Clock) subsystem provides **AP-side timer management** for the Super-100/Mini-100 supervisor. Its core functions include:
- **Task scheduling delays**: Enables tasks to sleep for specified intervals via a delta-encoded priority queue
- **Hardware timer control**: Direct manipulation of RTC device registers (`RTCCTL`, `RTCCST`, `RTCCTR`)
- **Interrupt-driven timeouts**: Handles RTC device interrupts (level 5) to wake sleeping tasks
- **Queue management**: Doubly-linked list with time-ordered insertion/ deletion
- **Optional hardware support**: Stubs in `NORTC.S` allow supervisor operation without RTC hardware

The subsystem integrates with the host communication layer (`FPUT`/`FGET`) and uses common memory blocks for queue headers and test data.

---

### 2. Per-File Purpose

#### RTC.S (275 lines)
- **$TITLE**: `RESTAR`, `ADDCLK`, `RMVCLK`  
- **$ENTRY**: `RESTAR`, `ADDCLK`, `RMVCLK`  
- **$EXT**: `EMPTY`, `RTCINT`, `RMVCLK`, `INSERT`, `DELETE`  
- **Purpose**: Core queue management routines.  
  - `RESTAR`: Starts RTC with first timeout in queue; halts if empty.  
  - `ADDCLK`: Inserts task into delta-encoded queue; restarts RTC if inserted at head.  
  - `RMVCLK`: Removes task from queue; fixes deltas and restarts RTC if head removed.  
- **AP State**:  
  - Uses **S-Pad** R0-R4 for queue traversal/deltas; DPX(0)-DPX(3) for parameters.  
  - Accesses **MD** for queue elements, TCB fields (`status`, `delta`, `links`).  
  - Programs **device registers**: `RTCCTL`, `RTCCST`, `RTCCTR`.  

#### RTCISR.S (101 lines)
- **$ISR**: `5.` (RTC interrupt level)  
- **$TITLE**: `RTCISR`  
- **$ENTRY**: `RTCISR`  
- **$EXT**: `INSERT`, `DELETE`  
- **Purpose**: Interrupt service routine for RTC timeouts. Stops RTC, removes expired message, reconfigures for next timeout, returns completed message.  
- **AP State**:  
  - Uses **S-Pad** R0-R6 (R0 saved in R6).  
  - Modifies **common block** `/RTCCOM/` (queue headers).  
  - Programs **device registers**: `RTCCTL`, `RTCCST`, `IMASK`.  
  - Manages **interrupt control** with `ION`/`IOFF`.  

#### RTCREQ.S (119 lines)
- **$TITLE**: `RTCREQ`  
- **$ENTRY**: `RTCREQ`, `RTCANS`  
- **$EXT**: `INSERT`, `ENABLE`, `DELETE`, `EMPTY`  
- **Purpose**: User-facing RTC API.  
  - `RTCREQ`: Submits timeout request; starts RTC if queue was empty.  
  - `RTCANS`: Polls for completed timeouts (supports non-blocking/busy-wait modes).  
- **AP State**:  
  - Uses **S-Pad** R0-R5; DPX(0)-DPX(3) for message addresses.  
  - Programs **device registers**: `RTCCTL`, `RTCCST`, `IMASK`.  
  - Modifies **common block** `/RTCCOM/` queues.  

#### RTCTST.S (62 lines)
- **$TITLE**: `TASK1`  
- **$ENTRY**: `TASK1`  
- **$EXT**: `FPUT`, `FGET`, `RTCANS`, `RTCREQ`  
- **Purpose**: Test task exercising RTC subsystem. Submits three timeouts (100,100,50 ticks), waits for timeouts, reports results to host.  
- **AP State**:  
  - Uses **common block** `/TESTC/` (message buffers).  
  - Manipulates **S-Pad** R0-R3, R7; DPX(0), DPX(3).  

#### RTCDUM.S (49 lines)
- **$TITLE**: `RTCDUM`  
- **$ENTRY**: None (data-only)  
- **Purpose**: Defines test messages for `RTCTST.S` with tick counts, rates, and linked list pointers.  
- **AP State**: Static data only; no runtime manipulation.  

#### NORTC.S (40 lines)
- **$TITLE**: `ADDCLK`, `RMVCLK`  
- **$ENTRY**: `ADDCLK`, `RMVCLK`  
- **$EXT**: None  
- **Purpose**: Stub routines for systems without RTC hardware. Both routines immediately `RETURN`.  
- **AP State**: None.  

---

### 3. Key Routines

#### RESTAR (RTC.S)
- **Calling Convention**: No parameters (implicitly uses global `CLKQUE`).  
- **Return**: Via `RETURN`.  
- **Side Effects**:  
  - **S-Pad**: R0-R3 modified; DPX(X2) = `CLKQUE`.  
  - **Device**: Writes `RTCCTL` (Halt/Run), `RTCCST` (clear interrupt).  
  - **MD**: Reads queue head via `EMPTY`, writes to `RTCCTR` (new counter value).  
- **Cross-References**: Called by `ADDCLK`, `RMVCLK`; calls `EMPTY`, `RTCINT`, `RMVCLK`.  

#### ADDCLK (RTC.S)
- **Calling Convention**: `DPX(0)` = wait time (ticks), `DPX(1)` = TCB address.  
- **Return**: Via `RETURN`.  
- **Side Effects**:  
  - **S-Pad**: R0-R4 modified; DPX(0)-DPX(3) used for queue traversal.  
  - **MD**: Modifies TCB (sets `CLKBIT` status, writes delta offset), adjusts queue links/deltas.  
- **Cross-References**: Calls `EMPTY`, `INSERT`, `RESTAR`.  

#### RMVCLK (RTC.S)
- **Calling Convention**: `DPX(1)` = TCB address.  
- **Return**: Via `RETURN`.  
- **Side Effects**:  
  - **S-Pad**: R0-R4 modified; DPX(2), DPX(3) for queue operations.  
  - **MD**: Clears `CLKBIT` in TCB, adjusts queue links/deltas.  
- **Cross-References**: Calls `EMPTY`, `DELETE`, `RESTAR`.  

#### RTCISR (RTCISR.S)
- **Calling Convention**: Interrupt entry; R0 = interrupt mask.  
- **Return**: Via `RETURN`; R0 restored from R6.  
- **Side Effects**:  
  - **S-Pad**: R0-R6 modified.  
  - **Device**: Programs `RTCCTL` (stop/start), `RTCCST` (read counter), `IMASK` (enable interrupt).  
  - **Common**: Modifies `/RTCCOM/` queues (delete expired, insert completed).  
- **Cross-References**: Calls `DELETE`, `INSERT`.  

#### RTCREQ (RTCREQ.S)
- **Calling Convention**: `DPX(0)` = message address.  
- **Return**: R0 = 0 (success).  
- **Side Effects**:  
  - **S-Pad**: R0-R5 modified; DPX(0)-DPX(3) for message/queue addresses.  
  - **Device**: Programs `RTCCTL`, `RTCCST`, `IMASK`.  
- **Cross-References**: Calls `INSERT`, `ENABLE`.  

#### RTCANS (RTCREQ.S)
- **Calling Convention**: R0 = 0 (poll) or ≠0 (busy-wait).  
- **Return**: R0 = 0 (no buffer) or 1 (buffer); `DPX(3)` = buffer address.  
- **Side Effects**:  
  - **S-Pad**: R0-R5 modified; DPX(2), DPX(3) for return queue.  
- **Cross-References**: Calls `EMPTY`, `DELETE`.  

---

### 4. Architectural Insights

#### Delta-Encoded Priority Queue
- The RTC queue uses **delta-encoding** for efficiency:  
  - Each element stores time *delta* from previous, not absolute time.  
  - `ADDCLK` inserts by walking queue, accumulating deltas, adjusting when inserting.  
  - `RMVCLK` fixes next element's delta when removing (preserves total time invariance).  
- **Efficiency**: Only head element needs handling on timeout; no global adjustment needed.  

#### Interrupt Management
- **Hardware ISR**: Interrupt level 5 handles RTC timeouts.  
  - Minimal context save: Only R0 saved (in R6), implying hardware saves S-Pad or supervisor ensures minimal live registers.  
  - **Reentrant design**: `ION` at entry, `IOFF` during critical sections (`DELETE`/`INSERT`).  
- **Polled vs. Interrupt**: Supports both (`RTCANS` for polling, `RTCISR` for interrupts).  

#### Device Register Layout
- **RTCCTL**: Control register.  
  - Write: `0` (Halt), `441` (Run with rate + direction/mode bits).  
- **RTCCST**: Status/command.  
  - Write: `0` (clear interrupt), `-1` (177777 octal) to test counter.  
  - Read: Current count.  
- **RTCCTR**: Counter register.  
  - Read: Current timeout value.  
  - Write: New counter value.  
- **IMASK**: Interrupt mask. Read-modify-write to enable RTC interrupt.  

#### Queue Implementation
- **Doubly-linked list** with header nodes in `/RTCCOM/`.  
- **Offsets**: `RCLOCK` (right link), `ICLOCK` (delta value).  
- **Sentinel headers**: Initialized to point to themselves (`$DATA RTCQ (1) RTCQ`).  

#### Context Management
- **ISR Minimalism**: Only R0 saved, suggesting:  
  - Hardware saves S-Pad on interrupt, or  
  - Supervisor guarantees no live registers during interrupts.  
- **Priority levels**: ISR runs higher than user tasks (preemption-safe).  

---

### 5. Design Observations

#### Performance Optimizations
1. **STATMA Pipelining**:  
   ```apal
   STATMA                  "Wait for memory
   LDDA;DB=RTCCTL          "Setup address
   STATMA                  "Pipelined second wait
   ```
   Overlaps memory wait with register setup.  

2. **INCMA Field Access**:  
   ```apal
   INCMA                   "Fetch direction
   INCMA                   "Fetch mode
   OUT;DB=MD;INCMA         "Set ticks, fetch rate
   ```
   Advances through message fields without explicit addressing.  

3. **Self-Modifying Code**:  
   RUN command built by OR'ing rate with constant (`0441`):  
   ```apal
   AND R0,R1               "Mask rate
   OR R1,R2;OUT;DB=SPFN    "RUN command
   ```

#### Coding Patterns
1. **Status Bit Manipulation**:  
   - `CLKBIT` cleared via `AND# R0,R3; DB=SPFN` (conditional store based on prior arithmetic).  
2. **Queue Header Sentinels**: Headers point to themselves for empty-queue checks.  
3. **Error Handling**: Minimal (`CLR R0` for success); no complex error propagation.  
4. **Register Conventions**: R0-R4 reused across routines; DPX(0)-DPX(3) for parameters.  

#### 1979 Engineering Pragmatism
1. **Hardware Abstraction**: Direct device register access (no HAL).  
2. **Fixed-Point Arithmetic**: Time as integer ticks (no floating-point).  
3. **Optional Modules**: `NORTC.S` stubs allow supervisor without RTC.  
4. **Self-Contained Test**: `RTCTST.S` + `RTCDUM.S` form complete test suite reporting to host.  
5. **Minimal Context**: ISR saves only necessary registers (R0).  

#### Queue Management Idioms
- **Time-Ordered Insertion**: `ADDCLK` walks queue, accumulating deltas to find insertion point.  
- **Delta Fixup on Removal**: `RMVCLK` adjusts next element's delta to preserve total time.  
- **Head-Only Handling**: `RESTAR` only reads head delta for RTC counter (efficient head removal).  

This reveals a real-time system optimized for timer-based scheduling with efficient delta-queue management and minimal hardware abstraction.

<details><summary>Cooperative drafts</summary>

#### DS coop

# RTC Subsystem Analysis — FPS-100/Mini-100 AP-Side Supervisor

## 1. Subsystem Overview

The RTC (Real-Time Clock) subsystem provides **AP-side timer management** for the Super-100/Mini-100 supervisor. It implements:

- **Task scheduling delays**: Allows tasks to sleep for specified time intervals
- **Timer queue management**: A delta-encoded priority queue of pending timer events
- **RTC hardware control**: Direct manipulation of the FPS-100's real-time clock device registers
- **Interrupt-driven timeouts**: The RTC generates interrupts when timers expire

The subsystem is **optional** — `NORTC.S` provides stub routines that return immediately, allowing the supervisor to function without RTC hardware.

## 2. Per-File Analysis

### RTC.S (275 lines) — Core RTC Queue Management

**$TITLE**: `RESTAR`, `ADDCLK`, `RMVCLK`

**$ENTRY**: `RESTAR`, `ADDCLK`, `RMVCLK`

**$EXT**: `EMPTY`, `RTCINT`, `RMVCLK`, `INSERT`, `DELETE`, `RESTAR`

**Purpose**: Three main routines that manage the delta-encoded timer queue:

1. **RESTAR** — Restarts the RTC with the timeout of the first task in the queue. If queue is empty, stops the clock.
2. **ADDCLK** — Inserts a new task into the clock queue with proper delta computation. If inserted at head, calls RESTAR.
3. **RMVCLK** — Removes a task from the clock queue, fixes up delta factors. If head task, calls RESTAR.

**AP State Manipulated**:
- **Device registers**: `RTCCTL`, `RTCCST`, `RTCCTR` (RTC control/status/counter)
- **S-Pad**: R0-R4 used extensively; DPX(0)-DPX(3) for parameters
- **MD**: Queue elements, TCB fields (status, clock delta, links)
- **APSTAT**: `STATMA`/`STATMA` sequences for memory synchronization

---

### RTCISR.S (101 lines) — RTC Interrupt Service Routine

**$ISR**: `5.` (Interrupt level 5 — RTC)

**$TITLE**: `RTCISR`

**$ENTRY**: `RTCISR`

**$EXT**: `INSERT`, `DELETE`

**Purpose**: Handles RTC interrupts. When a timer expires:
1. Stops the RTC
2. Removes the expired message from the RTC queue
3. Reconfigures the RTC for the next pending timer (if any)
4. Returns the completed message to the return queue (`RTCRQ`)

**AP State Manipulated**:
- **Device registers**: `RTCCTL`, `RTCCST`, `RTCCTR`
- **Interrupt control**: `ION`/`IOFF` for interrupt enable/disable
- **Common block**: `/RTCCOM/` containing `RTCQ` and `RTCRQ` queue headers
- **S-Pad**: R0-R6; DPX(2), DPX(3) for queue operations

---

### RTCREQ.S (119 lines) — RTC Request/Answer Handler

**$TITLE**: `RTCREQ`

**$ENTRY**: `RTCREQ`, `RTCANS`

**$EXT**: `INSERT`, `ENABLE`, `DELETE`, `EMPTY`

**Purpose**: Two routines for user-level RTC interaction:

1. **RTCREQ** — Submits a timer request message to the RTC queue. If queue was empty, starts the RTC hardware.
2. **RTCANS** — Polls for completed timer messages from the return queue. Supports both non-blocking (R0=0) and busy-wait (R0≠0) modes.

**AP State Manipulated**:
- **Device registers**: `RTCCTL`, `RTCCST`, `IMASK` (interrupt mask)
- **Common block**: `/RTCCOM/` queue headers
- **Interrupt control**: `ION`/`IOFF`
- **S-Pad**: R0-R5; DPX(0)-DPX(3)

---

### RTCTST.S (62 lines) — RTC Test Task

**$TITLE**: `TASK1`

**$ENTRY**: `TASK1`

**$EXT**: `FPUT`, `FGET`, `RTCANS`, `RTCREQ`

**Purpose**: A test task that exercises the RTC subsystem:
1. Gets a buffer via `FGET`
2. Sends three timer messages with different intervals (100, 100, 50 ticks)
3. Loops waiting for timeouts, re-queues each message, and sends results to host via `FPUT`

**AP State Manipulated**:
- **Common block**: `/TESTC/` containing MSG1, MSG2, MSG3
- **S-Pad**: R0-R3, R7; DPX(0), DPX(3)
- **Host communication**: `FPUT`/`FGET` for host messages

---

### RTCDUM.S (49 lines) — Test Data Definitions

**$TITLE**: `RTCDUM`

**$ENTRY**: None (data only)

**Purpose**: Defines three test messages (MSG1, MSG2, MSG3) with:
- Message numbers 1, 2, 3
- Tick counts: 100, 100, 50
- Rates: 12, 11, 12
- Repeat count: -1 (infinite)
- Self-referencing linked list pointers (initialized as empty queues)

---

### NORTC.S (40 lines) — No-RTC Stubs

**$TITLE**: `ADDCLK`, `RMVCLK`

**$ENTRY**: `ADDCLK`, `RMVCLK`

**$EXT**: None

**Purpose**: Stub routines for systems without RTC hardware. Both `ADDCLK` and `RMVCLK` simply `RETURN` immediately, making all timer operations no-ops.

---

## 3. Key Routines

### RESTAR (RTC.S)

**Calling Convention**:
- **Arguments**: None (implicitly uses `CLKQUE` global)
- **Returns**: Via `RETURN` instruction

**Side Effects**:
- **S-Pad**: R0-R3 modified; DPX(X2) set to `CLKQUE`
- **Device**: `RTCCTL`, `RTCCST` written
- **MD**: Reads first queue element via `EMPTY`
- **Control Flow**: May call `RTCINT` and `RMVCLK` if count underflow

**Cross-References**: Called by `ADDCLK`, `RMVCLK`; calls `EMPTY`, `RTCINT`, `RMVCLK`

### ADDCLK (RTC.S)

**Calling Convention**:
- **Arguments**: `DPX(0)` = requested wait time, `DPX(1)` = TCB address
- **Returns**: Via `RETURN`

**Side Effects**:
- **S-Pad**: R0-R4 modified; DPX(0)-DPX(3) used as temporaries
- **Device**: `RTCCTR`, `RTCCST`, `RTCCTL` read/written
- **MD**: TCB fields (status, clock delta, links) modified
- **TCB**: Sets `CLKBIT` in status word; writes delta value

**Cross-References**: Calls `EMPTY`, `INSERT`, `RESTAR`

### RMVCLK (RTC.S)

**Calling Convention**:
- **Arguments**: `DPX(1)` = TCB address
- **Returns**: Via `RETURN`

**Side Effects**:
- **S-Pad**: R0-R4 modified; DPX(2), DPX(3) used
- **MD**: TCB status word modified (clears `CLKBIT`); queue links adjusted
- **TCB**: Clears clock queue status bit

**Cross-References**: Calls `EMPTY`, `DELETE`, `RESTAR`

### RTCISR (RTCISR.S)

**Calling Convention**:
- **Entry**: Via interrupt (no explicit call)
- **Arguments**: R0 = interrupt bit mask (from hardware)
- **Returns**: Via `RETURN`; R0 restored from R6

**Side Effects**:
- **S-Pad**: R0-R6 modified; DPX(2), DPX(3) used
- **Device**: `RTCCTL`, `RTCCST`, `RTCCTR` read/written
- **Common**: `/RTCCOM/` queues modified
- **Interrupts**: `ION` at entry, `IOFF` before return

**Cross-References**: Calls `DELETE`, `INSERT`

### RTCREQ (RTCREQ.S)

**Calling Convention**:
- **Arguments**: `DPX(0)` = message address
- **Returns**: R0 = 0 (no errors)

**Side Effects**:
- **S-Pad**: R0-R5 modified; DPX(2), DPX(3) used
- **Device**: `RTCCTL`, `RTCCST`, `IMASK` written
- **Common**: `/RTCCOM/` queue modified
- **Interrupts**: `IOFF`/`ION` around queue manipulation

**Cross-References**: Calls `INSERT`, `ENABLE`

### RTCANS (RTCREQ.S)

**Calling Convention**:
- **Arguments**: R0 = 0 (poll) or ≠0 (busy-wait)
- **Returns**: R0 = 0 (no buffer) or 1 (buffer available); `DPX(3)` = buffer address

**Side Effects**:
- **S-Pad**: R0-R5 modified; DPX(2), DPX(3) used
- **Common**: `/RTCCOM/` return queue modified
- **Interrupts**: `IOFF`/`ION` around `DELETE`

**Cross-References**: Calls `EMPTY`, `DELETE`

---

## 4. Architectural Insights

### Delta-Encoded Priority Queue

The RTC queue uses a **delta-encoding scheme** where each element stores the time difference from the previous element, not absolute time. This is evident in:
- `ADDCLK` computing deltas by subtracting accumulated times (`SUB R0,R2`)
- `RMVCLK` fixing up the next element's delta when removing an element (`ADD R0,R4`)
- `RESTAR` reading the first element's delta to set the RTC counter

This is a classic embedded systems optimization — it minimizes the work needed when the head element expires (only the head needs to be removed; no global time adjustment needed).

### Interrupt-Driven vs Polled Operation

The subsystem supports **two modes**:
1. **Interrupt-driven** (RTCISR): The RTC generates interrupt 5 when a timer expires
2. **Polled** (RTCANS): User tasks can poll for completed timers

The `RTCANS` routine shows a **busy-wait** pattern (`BNE TEST` loop) — this is typical for a single-task or cooperative multitasking environment where the task has nothing else to do while waiting.

### Device Register Programming

The code reveals the RTC device register layout:
- `RTCCTL` — Control register (write RUN/HALT instructions)
- `RTCCST` — Status/command register (clear count, clear interrupt)
- `RTCCTR` — Counter register (read current count, write new count)
- `IMASK` — Interrupt mask register (enable/disable RTC interrupt)

The RTC control word is built from:
- Direction bit (bit 0)
- Mode bit (bit 0, shifted)
- Rate field (4 bits, mask 017 octal)
- RUN bit (bit 8, value 0401 octal)

### Queue Implementation

The queue is a **doubly-linked list** with:
- `RCLOCK` offset for right link
- `ICLOCK` offset for delta time value
- Header nodes in `/RTCCOM/` common block

The `EMPTY` routine appears to be a generic queue operation that returns the first element (or indicates empty). The `INSERT` and `DELETE` routines are generic doubly-linked list operations.

### Context Management

The ISR (`RTCISR`) shows minimal context saving — only R0 is saved in R6. This suggests:
- The interrupt handler runs at a higher priority than user tasks
- Either the hardware saves/restores context, or the supervisor guarantees that only certain registers are live during interrupts
- The `ION` at entry enables nested interrupts (re-entrant)

---

## 5. Design Observations

### Performance Tricks

1. **STATMA pipelining**: Multiple `STATMA` instructions are used to wait for memory operations without stalling the pipeline:
   ```apal
   STATMA                  "PUSH THE MEMORY
   LDDA;DB=RTCCTL          "SETUP DEVICE ADDR
   LDSPI R2;DB=FIXUP;      "R2 = RESTART INSTRUCTION
   STATMA                  "PUSH THE MEMORY
   ```
   This overlaps memory wait time with register setup.

2. **INCMA for field access**: The `INCMA` instruction is used to advance through message fields without explicit address arithmetic:
   ```apal
   INCMA                   "FETCH DIRECTION
   INCMA                   "FETCH MODE
   OUT;DB=MD;INCMA         "SET TICKS, FETCH RATE
   ```

3. **Register reuse**: The same register is often reused for multiple purposes across a routine, minimizing register pressure.

4. **Conditional execution**: The `MI<DB` pattern conditionally stores based on the previous arithmetic result.

### Coding Patterns

1. **Self-modifying code**: The `FIXUP` constant (0441 octal) is OR'd with the rate to build the RUN instruction — this is a form of parameterized instruction generation.

2. **Queue header as sentinel**: Queue headers are initialized to point to themselves (`$DATA RTCQ (1) RTCQ`), a classic linked-list sentinel pattern.

3. **Status bit manipulation**: The `CLKBIT` is set/cleared in the TCB status word using `AND#`/`OR` patterns, showing the supervisor's task state tracking.

4. **Error-return convention**: Most routines return with `CLR R0` to indicate success, following a consistent error code convention.

### 1979 Engineering Pragmatism

1. **Stub routines**: `NORTC.S` provides no-op implementations, allowing the same supervisor code to run on systems with or without RTC hardware.

2. **Test harness**: `RTCTEST.S` and `RTCDUM.S` form a self-contained test that exercises the subsystem and reports results to the host.

3. **Minimal abstraction**: The code directly manipulates device registers and memory — no HAL or device driver abstraction layer.

4. **Fixed-point arithmetic**: Time values are integer tick counts, not floating-point — appropriate for a real-time control system.

### Queue Management Idioms

The delta-encoded queue insertion algorithm in `ADDCLK`:
1. Walk the queue accumulating deltas
2. Find insertion point where accumulated time exceeds new request
3. Adjust the previous element's delta
4. Insert the new element

This is a **time-ordered insertion** that maintains the invariant that the sum of all deltas equals the total time until the last event.

#### GLM coop

### **1. Subsystem Overview**
The RTC subsystem manages real-time clock functionality for the AP-120B's Mini-100 supervisor, handling:
- **Timeout Scheduling**: Priority-ordered queues for task sleep requests.
- **Interrupt Handling**: Hardware RTC interrupt dispatch and event notification.
- **Device Control**: Programming the RTC hardware (rate, countdown, interrupts).
- **Host Communication**: Async message passing for timeout requests/responses.

Key architectural role: Implements a preemptive timer service allowing tasks to block on delays while maintaining system responsiveness.

---

### **2. Per-File Purpose**

#### **RTC.S** (275 lines)
- **Title**: `RESTAR`, `ADDCLK`, `RMVCLK`
- **Entries**: `RESTAR`, `ADDCLK`, `RMVCLK`
- **Externals**: `EMPTY` (COMSYS), `RTCINT` (not in-group), `INSERT` (COMSYS), `DELETE` (COMSYS)
- **Function**: 
  - `RESTAR`: Starts/stops RTC based on queue emptiness.
  - `ADDCLK`: Inserts TCB into time-ordered queue; restarts RTC if new head.
  - `RMVCLK`: Removes TCB from queue; fixes deltas and restarts RTC if needed.
- **State Manipulated**:
  - **DPX(X2,X3)**: Queue traversal, TCB addresses.
  - **MD**: RTCCTL/RTCCTR/RTCCST registers via `IN/OUT`.
  - **TM**: TCB fields (delta, status) via `LDSPI/STATMA`.

#### **RTCISR.S** (101 lines)
- **Title**: `RTCISR`
- **Entries**: `RTCISR` (ISR)
- **Externals**: `INSERT`, `DELETE` (COMSYS)
- **Function**: Handles RTC interrupts, dequeues expired TCBs, restarts RTC with next task.
- **State Manipulated**:
  - **DPX(X2,X3)**: Return queue insertion, message buffering.
  - **MD**: RTC registers, queue headers (RTCQ/RTCRQ from `/RTCCOM`).
  - **APSTAT**: Interrupt control (`ION/IOFF`).

#### **RTCREQ.S** (119 lines)
- **Title**: `RTCREQ`
- **Entries**: `RTCREQ`, `RTCANS`
- **Externals**: `INSERT`, `ENABLE`, `DELETE`, `EMPTY` (MINCOM)
- **Function**:
  - `RTCREQ`: Async timeout request enqueuing; starts RTC if idle.
  - `RTCANS`: Polls for expired TCBs (non-blocking/blocking modes).
- **State Manipulated**:
  - **DPX(X0-X3)**: Message addresses, queue headers.
  - **MD**: RTC registers, return queue (RTCRQ).

#### **RTCTST.S** (62 lines)
- **Title**: `TASK1`
- **Entries**: `TASK1`
- **Externals**: `FPUT`, `FGET`, `RTCANS`, `RTCREQ`
- **Function**: Test task sending timeout requests via `RTCREQ`, receiving responses via `RTCANS`, echoing to host with `FPUT`.
- **State Manipulated**:
  - **DPX(X0,X1)**: Message buffers from `/TESTC` common.
  - **MD**: Message data (countdown, rate).

#### **RTCDUM.S** (49 lines)
- **Title**: `RTCDUM`
- **Entries**: None (data section)
- **Externals**: None
- **Function**: Defines test message buffers (`MSG1`, `MSG2`, `MSG3`) with RTC parameters (tick count, rate, repeat count).
- **State Manipulated**: **MD**: Message buffer contents.

#### **NORTC.S** (40 lines)
- **Title**: `ADDCLK`, `RMVCLK`
- **Entries**: `ADDCLK`, `RMVCLK`
- **Externals**: None
- **Function**: Stubs for no-hardware scenarios (do-nothing routines).
- **State Manipulated**: None.

---

### **3. Key Routines**

#### **RESTAR** (RTC.S)
- **Calling Convention**: 
  - `DPX(X2)` = `CLKQUE` (clock queue head).
  - No explicit return value (uses `RETURN`).
- **Side Effects**:
  - Reads: `CLKQUE`, `RTCCTR`, `RTCCST`.
  - Writes: `RTCCTL` (halt/run), `RTCCTR` (set delta), `RTCCST` (clear interrupt).
  - APSTAT: Interrupt mask via `ION`/`IOFF`.
- **Cross-refs**: Calls `EMPTY`, `RTCINT` (for expired tasks).

#### **ADDCLK** (RTC.S)
- **Calling Convention**:
  - `DPX(X0)` = wait time.
  - `DPX(X1)` = TCB address.
- **Side Effects**:
  - Reads: `CLKQUE`, TCB status/delta fields.
  - Writes: TCB status/delta, queue links.
  - Modifies: RTC if new head.
- **Cross-refs**: Calls `EMPTY`, `INSERT`, `RESTAR`.

#### **RMVCLK** (RTC.S)
- **Calling Convention**:
  - `DPX(1)` = TCB address.
- **Side Effects**:
  - Reads: TCB status, queue links.
  - Writes: TCB status (clear bit), queue links.
  - Modifies: RTC if removed task was head.
- **Cross-refs**: Calls `EMPTY`, `DELETE`, `RESTAR`.

#### **RTCISR** (RTCISR.S)
- **Calling Convention**: 
  - Hardware interrupt vector 5.
  - Returns expired buffer in `DPX(3)`.
- **Side Effects**:
  - Reads: `RTCQ`, `RTCCTR` (current count).
  - Writes: `RTCCTL` (stop/start), `IMASK` (enable interrupt).
  - Uses `/RTCCOM` for queue management.
- **Cross-refs**: Calls `DELETE`, `INSERT`.

#### **RTCREQ** (RTCREQ.S)
- **Calling Convention**:
  - `DPX(X0)` = message address.
- **Side Effects**:
  - Writes: Request queue (`RTCQ`), RTC parameters if idle.
  - Uses `ION`/`IOFF` for atomic queue ops.
- **Cross-refs**: Calls `INSERT`, `ENABLE`.

#### **RTCANS** (RTCREQ.S)
- **Calling Convention**:
  - `DPX(1)` = test value (0=non-blocking, 1=blocking).
- **Side Effects**:
  - Reads: Return queue (`RTCRQ`).
  - Returns: Buffer in `DPX(3)` or `R0`=0.
- **Cross-refs**: Calls `EMPTY`, `DELETE`.

---

### **4. Architectural Insights**

#### **Interrupt Handling**
- **Nested Interrupts**: `ION`/`IOFF` usage suggests non-reentrant ISR design; interrupts disabled during critical sections.
- **APSTAT Observations**: ISR clears interrupt via `RTCCST` write and `OUT MD` to `SPFN`, revealing RTC interrupt acknowledge sequence.

#### **Memory Architecture**
- **DPX Register Usage**: `DPX(X2-X3)` heavily used for queue traversal (head/tail pointers, TCB addresses), suggesting DPX as a fast scratchpad for linked-list ops.
- **TM Access**: `LDSPI/STATMA` used for indirect TCB access, indicating Table Memory holds task control blocks.

#### **Queue Management**
- **Circular Linked Lists**: `RCLOCK`/`ICLOCK` offsets define forward/backward links. Queue sorted by deadline (earliest head).
- **Atomic Ops**: `ION`/`IOFF` around queue modifications prevent corruption during interrupts.

#### **Hardware Interaction**
- **RTC Programming**: Control via `RTCCTL` (run/halt), `RTCCTR` (countdown), `RTCCST` (status). Rate/direction encoded in low bits.
- **Device Acknowledges**: Interrupt cleared by writing to `RTCCST` and reading `INBS`.

#### **Host-RPC Mechanism**
- **Async Messaging**: `FPUT`/`FGET` in `RTCTST.S` imply host communication via buffered queues, not direct register access.

#### **Context Switching**
- **Task State**: TCBs store `CLKBIT` status (sleeping on clock) and delta times. ISR updates status on expiry.

---

### **5. Design Observations**

#### **Idioms**
- **Check-Then-Act**: `EMPTY` used to test queue emptiness before operations.
- **Register Preservation**: `DPX(1)` temporarily saved during `ADDCLK` (line 35).
- **Common Areas**: `/RTCCOM` and `/TESTC` for shared data vs. globals.

#### **Performance Tricks**
- **Lazy RTC Restart**: `RESTAR` only restarts RTC when queue head changes.
- **Delta Optimization**: `ADDCLK` avoids RTC restart if new task isn't head (lines 45-50).
- **Interrupt Minimization**: Critical sections wrapped in `ION`/`IOFF` (short duration).

#### **Concurrency Patterns**
- **Interrupt Safety**: All queue manipulations in `ADDCLK`/`RMVCLK`/`RTCISR` use interrupt disable.
- **Stubs for Testing**: `NORTC.S` allows compiling without hardware.

#### **Resource Management**
- **Buffer Reuse**: Return queue (`RTCRQ`) recycles expired buffers.
- **Message Format**: Fixed-size buffers (10 words) in `RTCDUM.S` for efficient packing.

#### **Error Handling**
- **Status Checks**: `RMVCLK` verifies `CLKBIT` before removal (line 10).
- **Queue Guards**: `RTCANS` returns `R0`=0 if no buffer (non-blocking mode).

#### **Modularity**
- **Separation of Concerns**: 
  - `RTC.S` core queue logic.
  - `RTCISR.S` pure interrupt handling.
  - `RTCREQ.S` async API for tasks.
  - `RTCTST.S` host integration test.

</details>



---

## Group: `boot_misc`

**Boot loaders + UPEX + tables + ENABLE/FUNC/ECHO**

Files: `BOOTMN.S`, `BOOTSP.S`, `UPEX.S`, `UPEXM.S`, `TABLES.S`, `ENABLE.S`, `FUNC.S`, `ECHO.S`

### DeepSeek final

(adv 72s, 15778c)

# Structured Analysis of FPS-100 AP-Side Supervisor Boot/Miscellaneous Files

## 1. Subsystem Overview

This group of files constitutes the **bootstrap, initialization, and host communication infrastructure** for the FPS-100's AP-side supervisor (Super-100/Mini-100). They provide:

- **System initialization** (BOOTMN.S, BOOTSP.S) - Cold-start bootstrap that configures AP hardware and transfers control to the supervisor
- **Task management infrastructure** (UPEX.S, UPEXM.S) - The "User APEX" task that dispatches host-called subroutines
- **System data structures** (TABLES.S) - Initialization of queues, configuration tables, and system common areas
- **Device management** (ENABLE.S) - Runtime lookup of interrupt mask bits for I/O devices
- **Host communication** (FUNC.S, ECHO.S) - Function interpreter for host commands and test/validation routines

These files work together with the supervisor core (OVHNDL, EXTASK, SENDER, WAIT referenced as externals) to create the complete AP-side operating environment.

## 2. Per-File Analysis

### BOOTMN.S - Mini-100 Bootstrap

| Attribute | Value |
|-----------|-------|
| **$TITLE** | BOOTSP (note: mismatched - title says BOOTSP but file is BOOTMN) |
| **$ENTRY** | BOOTSP |
| **$EXT** | OVHNDL |
| **$INSERT** | MINDEF, MINCOM |
| **$COMMON** | /DOT/ DTABLK(33.) /I |

**Purpose**: Cold-start bootstrap for the Mini-100 configuration. Initializes hardware state and jumps to the overlay handler.

**AP State Manipulated**:
- **IMASK register** = 175377 (enables Host DMA, Host non-DMA, and RTC interrupts)
- **RTC Control** = 034 (halts real-time clock)
- **APST3** = 0 (clears SRA - Save/Restore Address)
- **APST2** = 004260 (sets User Mode, User MA, interrupts enabled)
- **SSAREA** = start of save area (via LDOMA)
- **DPA** = 0
- **SWDB** = clears switch-ack flag

**Key Observation**: The Mini-100 bootstrap jumps to OVHNDL (overlay handler) rather than EXTASK, suggesting Mini-100 uses a different task dispatch mechanism than Super-100.

### BOOTSP.S - Super-100 Bootstrap

| Attribute | Value |
|-----------|-------|
| **$TITLE** | BOOTSP |
| **$ENTRY** | BOOTSP |
| **$EXT** | EXTASK, OVHNDL |
| **$INSERT** | SYSDEF |

**Purpose**: Cold-start bootstrap for the Super-100 configuration. Similar to BOOTMN but with different APST2 value and final jump target.

**AP State Manipulated**:
- **IMASK register** = 175377 (same as Mini-100)
- **RTC Control** = 034 (halts real-time clock)
- **APST2** = 052260 (sets Super Mode, User MA, interrupts enabled)
- **DPA** = 0
- **SWDB** = clears switch-ack flag

**Key Differences from BOOTMN**:
1. APST2 value: 052260 (Super Mode) vs 004260 (User Mode)
2. Final jump: EXTASK (execute task) vs OVHNDL (overlay handler)
3. No LDOMA to set SSAREA
4. Has fallthrough to OVHNDL after NOPs (possible error recovery)

### UPEX.S - User APEX Task

| Attribute | Value |
|-----------|-------|
| **$TASK** | 777 |
| **$TITLE** | UPEX |
| **$ENTRY** | UPEX,0 |
| **$EXT** | SENDER, WAIT |
| **$INSERT** | SYSDEF, FHOSTC |

**Purpose**: The primary task that handles host-invoked subroutine calls. It waits for messages from the host, loads user SPAD registers from the TCB, and transfers control to user code via the overlay handler.

**AP State Manipulated**:
- **DPX(X1)** = EXAPEX (message exchange identifier)
- **TMA** = loaded from MD (start address)
- **SPAD registers R0-R17** = loaded from MD (via loop UPX5)
- **SPD** = used as index for SPAD loading
- **SPFN** = used for function code

**Key Routines**:
- **UPEX**: Main loop - waits for message, loads SPADs from TCB, JSRT to user code, then calls SENDER with results
- **UPX5**: Loop that loads SPAD registers R16 down to R0 from consecutive MD locations

**Architectural Insight**: The comment "SUPERVISOR STATE RESTORE WILL LOAD TMA, SPADS, ETC. FROM TCB" reveals that the WAIT trap triggers a context switch that restores the task's state from its TCB before returning.

### UPEXM.S - Dummy APEX Task

| Attribute | Value |
|-----------|-------|
| **$TASK** | 777 /M |
| **$TITLE** | UPEX |
| **$ENTRY** | UPEX |

**Purpose**: A minimal placeholder for the APEX task in the MTS100 system. Provides the $TASK directive to force the loader to output tables and queues, and prevents the PS (Program Space) manager from becoming confused by zero-length routines.

**AP State Manipulated**: None (single NOP)

**Key Observation**: The `/M` suffix on $TASK 777 indicates this is a "mini" or alternate version for MTS100 compatibility.

### TABLES.S - System Tables and Configuration

| Attribute | Value |
|-----------|-------|
| **$TITLE** | SYSCOM (first section), CONFIG (second section) |
| **$COMMON** | /DOT/ DTABLK(33.) /I, /CONFIG/ DEV1-DEV15, /ISRMAP/ DUMMY(120.) /I |
| **$INSERT** | COMSYS |

**Purpose**: Initializes all system data structures including ready queue, clock queue, timeout queue, and I/O device configuration table.

**Data Structures Initialized**:

**System Queues** (in /DOT/ common):
- **RDYQUE** (4 words): Ready queue header - self-referencing doubly-linked list with priority 001000
- **NEWTSK, CURTSK, LSTFUL**: Task management variables
- **SYSAVE, SYSPTR, SYSTOP**: Save area management (SSAREA + SYSIZE-1)
- **CRATE**: Clock rate = 34
- **CLKQUE** (4 words): Clock queue header
- **NEVER** (6 words): "Never" queue for suspended tasks
- **MORGUE** (6 words): Terminated task queue
- **TIMOUT** (6 words): Timeout queue
- **LOGITS, LOGIOD**: Logging variables

**Device Configuration** (/CONFIG/ common):
15 device entries, each 5 words:
1. Priority mask
2. Bit mask (for IMASK)
3. Pointer to ISR in overlay map (ISRMAP + offset)
4. Device order number (EXP) / Physical address (LMAN)
5. Save area for old IMASK

**Device Mapping**:
| Device | Bit Mask | ISRMAP Offset | Physical Addr |
|--------|----------|---------------|---------------|
| DEV1 | 040000 | ISRMAP+0 | 0 |
| DEV2 | 020000 | ISRMAP+(W*1) | 0 |
| DEV3 | 010000 | ISRMAP+(W*2) | 0 |
| DEV4 | 004000 | ISRMAP+(W*3) | 0 |
| DEV5 (RTC) | 002000 | ISRMAP+(W*4) | 372 |
| DEV6 (Host DMA) | 001000 | ISRMAP+(W*5) | 0 |
| DEV7 (Host non-DMA) | 000400 | ISRMAP+(W*6) | 0 |
| DEV8 (IOP16 DMA) | 000200 | ISRMAP+(W*8) | 10 |
| DEV9 (IOP16 non-DMA) | 000100 | ISRMAP+(W*8) | 10 |
| DEV10 (IOP38 DMA) | 000040 | ISRMAP+(W*8) | 20 |
| DEV11 (IOP38 non-DMA) | 000020 | ISRMAP+(W*8) | 20 |
| DEV12 (IOP38 DMA) | 000010 | ISRMAP+(W*8) | 40 |
| DEV13 (IOP38 non-DMA) | 000004 | ISRMAP+(W*8) | 40 |
| DEV14 (GPIOP) | 000002 | ISRMAP+(W*13) | 100 |
| DEV15 (GPIOP) | 000001 | ISRMAP+(W*13) | 200 |

**Architectural Insight**: The overlay table width W=8 suggests each overlay entry is 8 words. The ISRMAP common area of 120 words can hold 15 entries (120/8=15), matching the 15 devices.

### ENABLE.S - Interrupt Enable Routine

| Attribute | Value |
|-----------|-------|
| **$TITLE** | ENABLE |
| **$ENTRY** | ENABLE |
| **$COMMON** | /CONFIG/ DEV1-DEV15, /ISRMAP/ DUMMY(120.) /I |

**Purpose**: Runtime routine to find the interrupt mask bit for a given device address by searching the configuration table.

**Calling Convention**:
- **Entry**: R0 = device address
- **Exit**: R4 = bit mask (0 if not found)

**AP State Manipulated**:
- **R1-R4**: Used as working registers
- **MD**: Accessed via SETMA/STATMA for table lookup

**Key Routine - ENABLE**:
```
ENABLE: R1 = DEV1+4 (first device address field)
        R2 = 15 (number of entries)
        R3 = 5 (entry length)
LOOP:   Fetch device address from table
        Compare with R0
        If match: R1-3, fetch bit mask at entry+1
        If no match: R4=0, RETURN;COM R4
```

**Design Pattern**: Uses `RETURN;COM R4` to set R4=0 (complement of 0 = -1, but the comment says "CLEAR R4 ERROR" - this may be a bug or the COM instruction works differently than expected).

### FUNC.S - Function Interpreter Task

| Attribute | Value |
|-----------|-------|
| **$TASK** | 776 |
| **$TITLE** | FUNC |
| **$ENTRY** | FUNC,0 |
| **$EXT** | SENDER, WAIT |
| **$INSERT** | SYSDEF, FHOSTC |
| **$COMMON** | /TCB777/ TCB(148.) |

**Purpose**: Interprets host commands (DEPOSIT, EXAM, and other functions) by reading messages from the host and manipulating AP registers via the TCB.

**AP State Manipulated**:
- **DPX(X1)** = EXFUNC (message exchange)
- **R0-R7**: Working registers
- **DPX(X0-X3)**: Data pad for results
- **MD**: Accessed for TCB fields
- **SPFN**: Used for function codes

**Key Routines**:

**FUNC** (main):
- Waits for message via WAIT trap
- Reads SWR value (APMSG+8) and FUNC value (APMSG+9)
- Decodes function fields:
  - Word field (bits 6-7, mask 60): R4
  - Deposit field (bit 9, mask 1000): Tests for DEPOSIT
  - Exam field (bit 8, mask 400): Tests for EXAM
  - Other functions: Calls INCADD
- Routes to FDEPS, FEXAMS, or NOFUNC

**FSELEC** (register select):
- Decodes select field (bits 0-4, mask 17)
- Returns value in DPX(X3) from TCB:
  - Select 00: NOFUNC (PSA not accessible)
  - Select 01: SPD register
  - Select 02: MA register
  - Select 03: TMA register
  - Select 04: DPA register
  - Select 05: SPFN value
  - Select 06: Status (STAT1)
  - Select 07: DA register
- R6 flag: 0 if MD deposit allowed, negative if not

**INCADD** (increment address):
- Decodes increment field (bits 8-9, mask 300)
- Routes to ICRMA (MA), ICRDPA (DPA), or ICRTMA (TMA)
- Increments the selected register in TCB

**TCB Layout Revealed** (offsets in words):
- TCB+SPD: SPD register
- TCB+MAREG: MA register
- TCB+TMAREG: TMA register
- TCB+DPA: DPA register
- TCB+SPFUNC: SPFN value
- TCB+STAT1: Status register 1
- TCB+DA: DA register

**Architectural Insight**: The TCB is 148 words long (TCB777), suggesting a rich task control block with saved state for all AP registers.

### ECHO.S - Host Interface Test

| Attribute | Value |
|-----------|-------|
| **$TASK** | 1 |
| **$TITLE** | ECHO |
| **$ENTRY** | ECHO |
| **$EXT** | FPUT, FGET, FTST, SENDER |

**Purpose**: Test program that validates host interface routines by echoing messages back to the host.

**AP State Manipulated**:
- **R1-R3**: Working registers
- **DPX, DPX(1)**: Data pad for message passing

**Key Routine - ECHO**:
```
ECHO:   R1=1, call FGET (wait for message type 1)
        Test R2 for valid message
        If error: HALT
CONT:   R1=0, call FTST (test for any message)
        Loop until message available
        R3=R2 (save datum)
        Call FPUT (echo back to same exchange)
        Also test SENDER path
        Loop to CONT
```

**Cross-References**: Uses FPUT, FGET, FTST (from host interface library) and SENDER (from supervisor).

## 3. Key Routines Summary

| Routine | File | Calling Convention | Side Effects | Cross-References |
|---------|------|-------------------|--------------|------------------|
| BOOTSP | BOOTMN.S | Entry point, no args | IMASK, RTC, APST2/3, DPA, SSAREA | OVHNDL |
| BOOTSP | BOOTSP.S | Entry point, no args | IMASK, RTC, APST2, DPA | EXTASK, OVHNDL |
| UPEX | UPEX.S | Task entry, no args | DPX, TMA, SPADs R0-R17, SPFN | SENDER, WAIT |
| UPEX | UPEXM.S | Task entry, no args | None | None |
| ENABLE | ENABLE.S | R0=dev addr, R4=bit mask | R1-R4, MD | CONFIG table |
| FUNC | FUNC.S | Task entry, no args | DPX, R0-R7, MD (TCB) | SENDER, WAIT |
| FSELEC | FUNC.S | R1 preserved, R6 flag, DPX(X3)=value | R0,R2,R6, DPX(X3), MD | TCB fields |
| INCADD | FUNC.S | R1 preserved, R2 flag | R2,R3, MD (TCB) | TCB fields |
| ECHO | ECHO.S | Task entry, no args | R1-R3, DPX | FPUT, FGET, FTST, SENDER |

## 4. Architectural Insights

### Context Management
The supervisor uses a **Task Control Block (TCB)** of 148 words to save/restore AP state. The WAIT trap triggers a context switch that restores TMA, SPADs, and other registers from the TCB before returning to the task. This is evident from comments in UPEX.S and the TCB field accesses in FUNC.S.

### Interrupt Dispatch
The configuration table (TABLES.S) reveals a sophisticated interrupt dispatch mechanism:
- 15 devices mapped to interrupt bits in IMASK
- Each device has a priority mask for nested interrupt handling
- ISR entry points are stored in an overlay map (ISRMAP) with 8-word entries
- Physical device addresses are stored for I/O operations

### Host Communication Protocol
The host communicates with AP tasks via **message exchanges**:
- EXAPEX (777) for subroutine calls
- EXFUNC (776) for function interpretation
- Messages are received via the WAIT trap
- Results are sent back via SENDER
- The ECHO test validates both FPUT/FGET and SENDER paths

### Memory Map
From the code we can deduce:
- **SSAREA**: Save area base (set by LDOMA in BOOTMN)
- **SYSIZE**: Save area size (SYSTOP = SSAREA + SYSIZE - 1)
- **APMSG+8, APMSG+9, APMSG+11**: Message buffer offsets for SWR, FUNC, and start address
- **TCB+offsets**: Various register save locations within the 148-word TCB

### Mode Differences
- **Super-100**: APST2=052260 (Super Mode), boots to EXTASK
- **Mini-100**: APST2=004260 (User Mode), boots to OVHNDL
- The Mini-100 also sets SSAREA explicitly, suggesting different memory management

## 5. Design Observations

### Performance Tricks

1. **Loop Unrolling via Countdown**: UPX5 uses `DEC R0; DB=SPFN; LDSPD; LDSP; DB=MD; DECMA; BNE UPX5` to load SPADs from high to low (R16→R0), using the DECMA to auto-increment the MD pointer.

2. **Conditional Branch Optimization**: FUNC.S uses `MOV R2,R2` as a test instruction (sets condition codes without modifying R2), followed by `AND# R1,R2` to test bits - avoids separate TST instruction.

3. **Register Reuse**: The `RETURN;COM R4` pattern in ENABLE.S combines return with register complement in a single instruction.

4. **Table-Driven Dispatch**: The device configuration table uses computed offsets (ISRMAP+(W*n)) for ISR dispatch, enabling O(1) lookup.

### Coding Patterns

1. **Self-Referencing Queues**: Queue headers point to themselves (RDYQUE(1)=RDYQUE, RDYQUE(2)=RDYQUE), indicating doubly-linked list initialization.

2. **Flag Encoding**: Multiple flags packed into single registers:
   - R6 in FSELEC: 0=MD deposit allowed, negative=not allowed
   - R0 in FSELEC: positive=unimplemented select, 0=38-bit value, negative=integer
   - R2 in INCADD: 1=not incremented, 0=incremented

3. **Error Propagation**: Error flags are passed through DPX(X2) in FUNC.S (0=OK, 2=unimplemented function).

4. **Hardware Initialization Sequence**: Bootstrap follows a strict order:
   1. Set IMASK (enable interrupts)
   2. Halt RTC
   3. Clear switch-ack flag
   4. Set save area pointer
   5. Clear DPA
   6. Set status registers
   7. Jump to supervisor

### 1979 Engineering Constraints

1. **Limited Branch Range**: FUNC.S uses `JMP FEXAMS` with comment "BECAUSE BRANCH IS OUT OF RANGE", showing awareness of the AP's limited branch displacement.

2. **Manual Pipeline Management**: `STATMA` instructions appear after `SETMA` to wait for MD access, showing explicit pipeline control.

3. **Memory Efficiency**: The UPEXM.S dummy task is specifically designed to be non-zero length to prevent PS manager confusion, showing awareness of edge cases in the overlay system.

4. **Octal Notation**: Constants are in octal (175377, 034, 004260, 052260), consistent with PDP-11/FPS-100 conventions.

### Cross-File Dependencies

```
BOOTMN.S → OVHNDL (from supervisor)
BOOTSP.S → EXTASK, OVHNDL (from supervisor)
UPEX.S → SENDER, WAIT (from supervisor)
FUNC.S → SENDER, WAIT (from supervisor)
ECHO.S → FPUT, FGET, FTST, SENDER (from host interface library)
TABLES.S → COMSYS (system definitions)
ENABLE.S → CONFIG table (from TABLES.S)
```

The bootstrap files (BOOTMN, BOOTSP) are the entry points that initialize hardware and transfer to the supervisor. The task files (UPEX, FUNC, ECHO) run under the supervisor and use its services (WAIT, SENDER). The data files (TABLES, ENABLE) provide system-wide structures and utilities.

### GLM final

(adv 2s, 40c)

ERROR: HTTP Error 429: Too Many Requests

<details><summary>Cooperative drafts</summary>

#### DS coop

# Structured Analysis: Boot/Miscellaneous APAL Source Files

## 1. Subsystem Overview

This group of files forms the **foundation layer** of the AP-side supervisor for the FPS-100 array processor running in Super-100 or Mini-100 mode. Together they provide:

- **Bootstrapping** (BOOTMN.S, BOOTSP.S) — Initial hardware configuration and supervisor entry
- **Task infrastructure** (UPEX.S, UPEXM.S) — The user subroutine execution environment (APEX)
- **System tables** (TABLES.S) — Queue structures and I/O device configuration
- **Device management** (ENABLE.S) — Interrupt mask lookup for I/O devices
- **Host communication** (FUNC.S) — Function interpreter for host-initiated register access
- **Testing** (ECHO.S) — Host interface verification

The code reveals a **message-passing, task-switching RTOS** where the AP runs independent tasks (identified by $TASK numbers) that communicate with the host via exchange mechanisms and with each other via system calls (SENDER, WAIT).

---

## 2. Per-File Analysis

### BOOTMN.S — Mini-100 Bootstrap

| Attribute | Value |
|-----------|-------|
| **$TITLE** | BOOTSP |
| **$ENTRY** | BOOTSP |
| **$EXT** | OVHNDL |
| **$INSERT** | MINDEF, MINCOM |
| **$COMMON** | /DOT/ DTABLK(33.) /I |

**Purpose:** Initializes the AP hardware for Mini-100 mode and transfers control to the overlay handler.

**Architectural state manipulated:**
- **IMASK register** → Set to 175377 (enables host and RTC interrupts)
- **RTC control** → Halted via HALTRC = 034
- **Switch-ack flag** → Cleared via SWDB
- **SMA (Save Area)** → Set to SSAREA via LDOMA
- **DPA** → Zeroed
- **APST3** → SRA=0
- **APST2** → Set to 004260 (user mode, user MA, interrupts on)

**Key difference from BOOTSP.S:** The Mini-100 bootstrap jumps to OVHNDL (overlay handler) rather than EXTASK, suggesting Mini-100 uses overlay-based task loading while Super-100 uses direct task execution.

---

### BOOTSP.S — Super-100 Bootstrap

| Attribute | Value |
|-----------|-------|
| **$TITLE** | BOOTSP |
| **$ENTRY** | BOOTSP |
| **$EXT** | EXTASK, OVHNDL |
| **$INSERT** | SYSDEF |

**Purpose:** Initializes the AP hardware for Super-100 mode and transfers to the executive task.

**Architectural state manipulated:**
- **IMASK register** → Set to 175377
- **RTC control** → Halted
- **Switch-ack flag** → Cleared
- **DPA** → Zeroed
- **APST2** → Set to 052260 (Super mode, user MA, interrupts on)

**Key difference from BOOTMN.S:** 
- APST2 value is 052260 vs 004260 — the difference indicates Super-100 mode vs Mini-100 mode
- Jumps to EXTASK instead of OVHNDL
- Has a fallback path: after NOPs, jumps to OVHNDL (possibly for error recovery)

---

### UPEX.S — User APEX Task

| Attribute | Value |
|-----------|-------|
| **$TASK** | 777 |
| **$TITLE** | UPEX |
| **$ENTRY** | UPEX,0 |
| **$EXT** | SENDER, WAIT |
| **$INSERT** | SYSDEF, FHOSTC |

**Purpose:** The user subroutine execution environment. Waits for host messages, loads user code context, and executes user subroutines.

**Key routine: UPEX**

**Calling convention:**
- Entry: No arguments (waits for message from host)
- Uses DPX(X1) ← EXAPEX (message exchange identifier)
- TRAP to WAIT with LDTMA (suspends until message arrives)

**Architectural state manipulated:**
- **TMA** → Loaded from APMSG+11 (start address)
- **SPAD registers R0-R17** → Loaded from MD via loop (UPX5)
- **SPD** → Used as index for SPAD loading
- **DPX** → Used for SENDER arguments

**Flow:**
1. Wait for host message via WAIT system call
2. Extract start address from message (APMSG+11)
3. Load all 18 SPAD registers from memory (FSPAD+17 down to FSPAD+0)
4. JSRT to user code (jump subroutine through TMA)
5. On return, call SENDER with SPFN as arguments
6. Loop back to wait for next message

**Cross-references:** SENDER (message sending), WAIT (task synchronization), FHOSTC (host communication constants)

---

### UPEXM.S — Dummy APEX Task

| Attribute | Value |
|-----------|-------|
| **$TASK** | 777 /M |
| **$TITLE** | UPEX |
| **$ENTRY** | UPEX |
| **$INSERT** | (none) |

**Purpose:** A minimal placeholder that provides:
- The $TASK directive to trigger loader table/queue generation
- A root for the host-callable subroutine tree
- MTS100 compatibility
- Prevents PS manager confusion with zero-length routines

**Key routine:** UPEX — single NOP instruction

**Architectural state:** None (no-op routine)

---

### TABLES.S — System Tables

| Attribute | Value |
|-----------|-------|
| **$TITLE** | SYSCOM, CONFIG |
| **$COMMON** | /DOT/ DTABLK(33.) /I, /CONFIG/ DEV1-DEV15, /ISRMAP/ DUMMY(120.) /I |
| **$INSERT** | COMSYS |

**Purpose:** Defines all system data structures and I/O device configuration tables.

**Data structures defined:**

**Queue headers (in /DOT/ common):**
- **RDYQUE** — Ready queue (4 words: forward/back pointers, task ID, flags=001000)
- **CLKQUE** — Clock queue (same format)
- **NEVER** — Never queue (6 words: queue header + 2 words for timeout data)
- **MORGUE** — Morgue queue (for terminated tasks)
- **TIMOUT** — Timeout queue
- **NEWTSK, CURTSK, LSTFUL** — Task management variables
- **SYSAVE, SYSPTR, SYSTOP** — Save area management (SSAREA + SYSIZE-1)
- **CRATE** — Clock rate (34)
- **LOGITS, LOGIOD** — Logging variables

**I/O Configuration Table (/CONFIG/):**
15 device entries, each 5 words:
1. Priority mask
2. Bit mask (for IMASK)
3. Pointer to ISR in overlay map (ISRMAP + offset)
4. Device order number (EXP) / Physical address (LMAN)
5. Save area for old IMASK

**Device mapping (by IMASK bit position):**
| Bit | Device |
|-----|--------|
| 0-3 | Devices 1-4 (unidentified) |
| 4 | Real-Time Clock (address 372) |
| 5 | Host DMA |
| 6 | Host non-DMA interrupt |
| 7 | IOP16 DMA |
| 8 | IOP16 non-DMA |
| 9 | IOP38 DMA (device 1) |
| 10 | IOP38 non-DMA (device 1) |
| 11 | IOP38 DMA (device 2) |
| 12 | IOP38 non-DMA (device 2) |
| 13 | GPIOP (device 1) |
| 14 | GPIOP (device 2) |

**Overlay table width:** W = 8 (8 words per ISR entry in overlay map)

---

### ENABLE.S — Interrupt Enable Routine

| Attribute | Value |
|-----------|-------|
| **$TITLE** | ENABLE |
| **$ENTRY** | ENABLE |
| **$COMMON** | /CONFIG/, /ISRMAP/ |
| **$INSERT** | (none) |

**Purpose:** Finds the interrupt mask bit for a given device address by searching the configuration table.

**Key routine: ENABLE**

**Calling convention:**
- **Entry:** R0 = device address
- **Exit:** R4 = bit mask (0 if not found)

**Architectural state:**
- **SPAD registers:** R0-R4 used
- **MD:** Accessed for table lookups
- **MA:** Used for indexed table access

**Algorithm:**
1. Initialize R1 = DEV1+4 (first device address field)
2. R2 = 15 (number of entries)
3. R3 = 5 (entry length)
4. Loop: fetch device address from table, compare with R0
5. If match: back up to bit mask field, return it
6. If no match: return 0 in R4

**Performance note:** Uses SETMA/STATMA sequence for MD synchronization — a common APAL idiom for memory access.

---

### FUNC.S — Function Interpreter Task

| Attribute | Value |
|-----------|-------|
| **$TASK** | 776 |
| **$TITLE** | FUNC |
| **$ENTRY** | FUNC,0 |
| **$EXT** | SENDER, WAIT |
| **$INSERT** | SYSDEF, FHOSTC |
| **$COMMON** | /TCB777/ TCB(148.) |

**Purpose:** Interprets host-initiated function calls (DEPOSIT, EXAM, OTHER) for accessing AP registers and memory. Task 776 in the system.

**Key routine: FUNC**

**Calling convention:**
- Entry: Waits for message via WAIT with EXFUNC exchange
- Message format (from APMSG+8):
  - SWR value (word to store)
  - FUNC value (function code)

**FUNC value bit fields:**
- Bits 0-5: Word field (shifted by 2)
- Bits 6-7: Deposit field (1000 mask)
- Bits 8-9: Exam field
- Bits 10-11: Inc field (300 mask)
- Bits 12-16: Select field (17 mask)

**Subroutines:**

**FSELEC — Register Select**
- Processes the select field (bits 12-16)
- Returns value in DPX(X3)
- Select values:
  - 00: PSA (not accessible — jumps to NOFUNC)
  - 01: SPD register
  - 02: MA register
  - 03: TMA register
  - 04: DPA register
  - 05: SPFN register
  - 06: AP status (STAT1)
  - 07: DA register
- R6 flag: 0 if MD deposit allowed, negative if not

**INCADD — Increment Address Register**
- Processes the inc field (bits 10-11)
- Values: 0=none, 1=inc MA, 2=inc DPA, 3=inc TMA
- Reads from TCB+TMAREG, TCB+DPA, or TCB+MAREG
- R2 return: 1 if not incremented, 0 if incremented

**ICRMA, ICRDPA, ICRTMA — Specific increment routines**
- Each fetches the appropriate register from TCB
- Increments and stores back via SPFN

**Architectural state:**
- **TCB** (Task Control Block at /TCB777/): Read/written for register values
- **DPX:** Used for return values and SENDER arguments
- **SPAD:** R0-R7 used extensively
- **MD:** Accessed for TCB fields

**Error handling:** Unimplemented functions set DPX(X2)=2 (error flag)

---

### ECHO.S — Host Interface Test

| Attribute | Value |
|-----------|-------|
| **$TASK** | 1 |
| **$TITLE** | ECHO |
| **$ENTRY** | ECHO |
| **$EXT** | FPUT, FGET, FTST, SENDER |

**Purpose:** Test program for host interface routines. Echoes messages back to host.

**Key routine: ECHO**

**Calling convention:**
- Uses FGET to wait for message (R1=1)
- Uses FTST to poll for messages (R1=0)
- Uses FPUT to echo back
- Uses SENDER for alternate path test

**Flow:**
1. Wait for first message via FGET
2. Validate message (R2 test)
3. Poll for any available message via FTST
4. Echo valid message back via FPUT
5. Also test SENDER path
6. Loop continuously

**Architectural state:**
- **SPAD:** R0-R5 used
- **DPX:** Used for SENDER arguments

---

## 3. Key Routines Summary

### BOOTSP (both versions)
| Aspect | Detail |
|--------|--------|
| **Args** | None |
| **Side effects** | IMASK, RTC, APST2, APST3, SMA, DPA |
| **Cross-refs** | OVHNDL (overlay handler), EXTASK (executive task) |

### UPEX
| Aspect | Detail |
|--------|--------|
| **Args** | None (message-driven) |
| **Side effects** | All SPADs loaded, TMA set, DPX modified |
| **Cross-refs** | SENDER, WAIT, FHOSTC |

### ENABLE
| Aspect | Detail |
|--------|--------|
| **Args** | R0=device address |
| **Returns** | R4=bit mask |
| **Side effects** | R1-R3 modified, MA used |
| **Cross-refs** | /CONFIG/ table |

### FUNC subroutines
| Routine | Args | Returns | Side Effects |
|---------|------|---------|--------------|
| FUNC | Message-driven | Via SENDER | TCB read/write, DPX modified |
| FSELEC | R1=func value | DPX(X3)=value, R6=flag | TCB read |
| INCADD | R1=func value | R2=flag | TCB read/write (MA/DPA/TMA) |

---

## 4. Architectural Insights

### Supervisor Context Management
The code reveals a sophisticated context-switching mechanism:

1. **TCB (Task Control Block)** at /TCB777/ contains 148 words including:
   - TMAREG, MAREG, DPA, SPD, SPFUNC, STAT1, DA registers
   - SPAD save area (FSPAD)
   - The supervisor restores TMA, SPADs, etc. from TCB on task dispatch

2. **Save Area Management:**
   - SSAREA is the system save area base
   - SYSPTR tracks current save position
   - SYSTOP = SSAREA + SYSIZE - 1 (boundary check)
   - Stack-like allocation for context saves

### Interrupt Dispatch Architecture
The TABLES.S configuration reveals a **priority-based interrupt system**:

1. **IMASK register** has 15 bits, each mapped to a device
2. **Priority masking:** Each device entry has a priority mask that masks lower-priority devices
3. **ISR dispatch:** Device entries point to ISRMAP + offset (overlay table)
4. **Overlay table width** is 8 words per entry
5. **Device address encoding:** Word 4 combines EXP (device order) and LMAN (physical address)

### Host RPC Implementation
The FUNC.S and UPEX.S files reveal a **message-based RPC mechanism**:

1. **Exchange identifiers:** EXAPEX (for user subroutines), EXFUNC (for function interpreter)
2. **Message format:** APMSG contains SWR value, function code, start address
3. **Synchronization:** WAIT system call suspends task until message arrives
4. **Return path:** SENDER system call sends results back to host

### Task Numbering Convention
- **Task 1:** ECHO (test program)
- **Task 776:** FUNC (function interpreter)
- **Task 777:** UPEX (user subroutine execution)
- The /M suffix on UPEXM.S indicates a Mini-100 variant

### Queue Management
The system uses **doubly-linked circular queues** with 4-word headers:
- Word 1: Forward pointer
- Word 2: Backward pointer
- Word 3: Task ID
- Word 4: Flags (001000 = queue active)

Special queues (NEVER, MORGUE, TIMOUT) have 6-word entries with additional timeout data.

---

## 5. Design Observations

### APAL Programming Idioms

1. **MD Synchronization Pattern:**
   ```apal
   SETMA       ; Set memory address
   STATMA      ; Wait for MD ready
   STATMA      ; Double wait (pipeline synchronization)
   LDSPI R4;DB=MD  ; Load from MD
   ```
   The double STATMA is a common APAL idiom for ensuring pipeline completion.

2. **Conditional Branch with Side Effects:**
   ```apal
   BEQ FSEL00; DEC R2    ; Branch and decrement in delay slot
   ```
   Uses the branch delay slot for useful work.

3. **Register Initialization:**
   ```apal
   CLR R0; DPX(X0)<SPFN  ; Clear R0 and set DPX in parallel
   ```
   Multiple operations in single instruction.

4. **Loop with Decrement and Branch:**
   ```apal
   DEC R0; DB=SPFN;      ; Decrement, set SPFN
       LDSPD              ; Set SPD
   LDSP; DB=MD;          ; Load SPAD
       DECMA; BNE UPX5   ; Decrement MA, branch if not zero
   ```
   Tight loop with minimal overhead.

### Performance Optimizations

1. **Table lookup with indexed addressing:**
   ```apal
   MOV R1,R1;SETMA       ; Move R1 to itself (NOP) with SETMA
   STATMA;ADD R3,R1      ; Wait, then add entry length
   ```
   Uses the MD pipeline for sequential table access.

2. **Immediate value encoding:**
   Constants like 175377, 052260, 004260 are encoded as octal values — standard for PDP/AP architecture.

3. **Minimal context save/restore:**
   The UPEX task only loads SPADs R0-R17, relying on supervisor to restore other context from TCB.

### Error Handling Patterns

1. **Error flags:** FUNC returns DPX(X2)=2 for unimplemented functions
2. **HALT on error:** ECHO.S uses HALT for fatal errors
3. **Fallback paths:** BOOTSP.S has NOPs followed by OVHNDL jump (error recovery)

### Code Organization

1. **Separate files for different modes:** BOOTMN.S vs BOOTSP.S for Mini-100 vs Super-100
2. **Dummy task for loader:** UPEXM.S provides $TASK without actual code
3. **Common blocks for shared data:** /DOT/, /CONFIG/, /ISRMAP/, /TCB777/
4. **Insert files for definitions:** SYSDEF, MINDEF, MINCOM, COMSYS, FHOSTC

### Notable Constants

- **IOMASK = 175377:** Enables bits 0-14 (all devices except possibly bit 15)
- **HALTRC = 034:** RTC halt command
- **STATU2 values:** 004260 (Mini-100) vs 052260 (Super-100) — the difference indicates mode bits
- **CRATE = 34:** Clock rate (likely 34 Hz or some divisor)
- **W = 8:** Overlay table entry width

This code represents a well-structured, modular RTOS for a 1979-era array processor, demonstrating sophisticated interrupt handling, task management, and host communication in a resource-constrained environment.

#### GLM coop

ERROR: HTTP Error 429: Too Many Requests

</details>



---

## Group: `tests`

**Test programs + sequence vectors**

Files: `TASK51.S`, `TASK52.S`, `TASK53.S`, `TEST2.S`, `SEQV1.S`, `SEQV2.S`, `SHOOT.S`, `SHOOTM.S`, `SUB1.S`, `SUB2.S`, `SUBR1.S`, `SUBR2.S`, `SUBR3.S`, `SUBR4.S`

### DeepSeek final

(adv 58s, 12912c)

# Analysis of FPS-100 APAL Test Suite Files

## 1. Subsystem Overview

This group of files constitutes the **test and validation subsystem** for the Super-100/Mini-100 AP-side supervisor. They exercise fundamental OS mechanisms:

- **Task scheduling** (TASK51-53.S): Three concurrent tasks demonstrating the multitasking kernel
- **Host interface** (TEST2.S): Tests the message-passing RPC mechanism between host and AP
- **Sequence generation** (SEQV1-2.S): Utility routines for building test data vectors
- **HASI (Host AP Software Interface) tests** (SHOOT.S, SHOOTM.S, SUB1.S, SUB2.S, SUBR1-4.S): Validate the Fortran-callable AP subroutine interface and common block sharing

The files reveal a **layered test strategy**: unit tests of OS primitives (TASK*, TEST2), utility routines (SEQV*), and integration tests of the HASI Fortran interface (SHOOT*, SUB*).

## 2. Per-File Purpose

### TASK51.S ($TITLE TASK1)
- **$ENTRY**: TASK1
- **$EXT**: FPUT, TWAIT
- **Purpose**: Task 1 of a 3-task concurrency test. Waits 30 time units for a message, increments a flag at address 17700, sends a response via FPUT, loops.
- **AP state**: Uses S-Pad R0-R3, DPX(0) for time parameter, DPX(1) for exchange data. Writes to MD location 17700 (flag). Uses TRAP to invoke TWAIT.

### TASK52.S ($TITLE TASK2)
- **$ENTRY**: TASK2
- **$EXT**: FPUT, TWAIT
- **Purpose**: Task 2, identical structure to TASK1 but with ID=2, TIME1=45, FLAG1=17701.
- **AP state**: Same pattern, different constants.

### TASK53.S ($TITLE TASK3)
- **$ENTRY**: TASK3
- **$EXT**: FPUT, TWAIT
- **Purpose**: Task 3, ID=3, TIME1=61, FLAG1=17702.
- **AP state**: Same pattern.

### TEST2.S ($TITLE ECHO)
- **$ENTRY**: ECHO
- **$EXT**: FPUT, FGET, FTST, SENDER
- **Purpose**: Echo test of host interface. Waits for message on exchange 1, then continuously polls for any message and echoes it back via both FPUT and SENDER paths.
- **AP state**: Uses R1-R5, DPX(1) for exchange data. Tests FGET (blocking receive), FTST (non-blocking poll), FPUT (send), SENDER (alternate send path).

### SEQV1.S ($TITLE SEQV1)
- **$ENTRY**: SEQV1
- **$EXT**: None
- **Purpose**: Builds a descending integer vector (31 down to 0) into SARRAY. Uses constants from SEQV1.DAT.
- **AP state**: Uses R0, MA (Memory Address) register. Writes to MD array SARRAY.

### SEQV2.S ($TITLE SEQV2)
- **$ENTRY**: SEQV2
- **$EXT**: None
- **Purpose**: Builds a descending integer vector (32 down to 1) into SARRAY starting at address 0.
- **AP state**: Uses R0, MA register. Writes to MD.

### SHOOT.S ($TITLE SHOOT)
- **$ENTRY**: SHOOT
- **$EXT**: FPUT
- **$COMMON**: /PUT/ COUNT, W, X, Y, Z (all integer)
- **Purpose**: Sends 5 elements from COMMON block /PUT/ to exchanges 2-6 via FPUT. Demonstrates COMMON block access from APAL.
- **AP state**: Uses S-Pad 13 (pointer to COMMON), 14 (exchange counter), 15 (loop counter), 2 (data to send). Reads MD via COMMON.

### SHOOTM.S ($TITLE SHOOT)
- **$ENTRY**: SHOOT
- **$EXT**: FPUT
- **$COMMON**: /PUT/ COUNT, W, X, Y, Z
- **Purpose**: Identical to SHOOT.S but with REL 1.0 (minor revision). Same algorithm.

### SUB1.S ($TITLE SUBR1)
- **$ENTRY**: SUBR1 (13 S-Pad parameters)
- **$COMIO**: PASS 1
- **$COMMON**: /PASS/ IT(17) integer array
- **$DATA**: IT(1)=0
- **Purpose**: Copies S-Pad registers 0-15 into COMMON block /PASS/, increments a count stored at IT. Demonstrates S-Pad-to-COMMON bulk transfer.
- **AP state**: Reads/writes all S-Pad 0-15, uses SPD (S-Pad Data pointer) for indexed access, writes to MD COMMON area.

### SUB2.S (AP Fortran source, not APAL)
- **Purpose**: Fortran test subroutine that performs integer arithmetic, updates COMMON /PUT/, calls APOVLD(3) (AP overlay load?), and calls SHOOT.
- **Note**: This is a host-side Fortran source, not APAL. Included for context.

### SUBR1.S ($TITLE SUBR1)
- **$ENTRY**: SUBR1 (13 S-Pad parameters)
- **$COMIO**: PASS 1
- **$COMMON**: /PASS/ IT(17)
- **$DATA**: IT(1)=0
- **Purpose**: Identical to SUB1.S but with REL A.0. Same algorithm.

### SUBR2.S (AP Fortran source)
- **Purpose**: Same as SUB2.S but REL A.0. Fortran test routine.

### SUBR3.S ($TITLE SUBR3)
- **$ENTRY**: SUBR3 (2 S-Pad parameters)
- **Purpose**: Writes S-Pad 0,1 to MD address 17700, then writes their sum. Minimal test of MD write and arithmetic.
- **AP state**: Uses R0,R1, writes to MD 17700-17702.

### SUBR4.S ($TITLE SUBR4)
- **$ENTRY**: SUBR4 (0 parameters)
- **Purpose**: Reads a "COUNT" location via RPSL (Read Processor Status Long), increments it, writes back via LPSL. Demonstrates direct status register manipulation.
- **AP state**: Reads/writes a status location labeled COUNT (NOP placeholder). Uses DPX as temporary.

## 3. Key Routines

### TASK1/TASK2/TASK3 (TASK51-53.S)
**Calling convention**: Entry point, no parameters. Runs as an OS task.
```
S-Pad usage:
  R0 = loop counter (run count)
  R1 = task ID (loaded from ID1 constant)
  R2 = run flag copy
  R3 = run flag accumulator
  DPX(0) = time parameter for TWAIT
  DPX(1) = exchange data (EXDAT1)
```
**Side effects**: 
- Writes to MD at FLAG1 (17700-17702)
- Invokes TWAIT via TRAP (blocks task)
- Calls FPUT (sends message to host)
- **Cross-refs**: FPUT, TWAIT (external)

### ECHO (TEST2.S)
**Calling convention**: Entry point, no parameters.
```
S-Pad usage:
  R1 = exchange number (1 for initial wait, 0 for poll)
  R2 = message validity flag / received datum
  R3 = datum to echo
  R4,R5 = unused
```
**Side effects**:
- Calls FGET (blocking receive)
- Calls FTST (non-blocking poll)
- Calls FPUT (send)
- Calls SENDER (alternate send)
- HALT on error
- **Cross-refs**: FPUT, FGET, FTST, SENDER

### SEQV1/SEQV2 (SEQV1-2.S)
**Calling convention**: Entry point, no parameters. Returns via RETURN.
```
S-Pad usage:
  R0 = current value to write (decremented each iteration)
```
**Side effects**:
- MA (Memory Address) register: set to end of SARRAY, decremented through loop
- Writes to MD array SARRAY
- **Cross-refs**: None

### SHOOT (SHOOT.S, SHOOTM.S)
**Calling convention**: Entry point, no parameters. Uses COMMON /PUT/.
```
S-Pad usage:
  13 = pointer to COMMON element list (PUT)
  14 = exchange destination (2-6)
  15 = loop counter (5)
  2 = data element to send
  1 = exchange destination (via MOV 14,1)
```
**Side effects**:
- Reads COMMON block /PUT/ from MD
- Calls FPUT 5 times
- **Cross-refs**: FPUT, COMMON /PUT/

### SUBR1 (SUB1.S, SUBR1.S)
**Calling convention**: Entry with 13 S-Pad parameters. Returns via RETURN.
```
S-Pad usage:
  0 = SPD pointer (initialized to 3)
  1 = loop counter (13)
  2 = accumulator (cleared, then accumulates S-Pad values)
  All S-Pads 0-15 read and written to COMMON
```
**Side effects**:
- Writes all 16 S-Pad values to COMMON /PASS/ in MD
- Increments count at IT
- Uses SPD (S-Pad Data pointer) for indexed S-Pad access
- **Cross-refs**: COMMON /PASS/

### SUBR3 (SUBR3.S)
**Calling convention**: Entry with 2 S-Pad parameters.
```
S-Pad usage:
  0 = first parameter
  1 = second parameter
```
**Side effects**:
- Writes to MD 17700, 17701, 17702
- Performs ADD 0,1 and stores result
- **Cross-refs**: None

### SUBR4 (SUBR4.S)
**Calling convention**: Entry with 0 parameters.
```
S-Pad usage:
  0 = temporary (loaded from DPX)
  DPX = temporary for status value
```
**Side effects**:
- Reads/writes status register via RPSL/LPSL
- Uses COUNT label (NOP) as status register placeholder
- **Cross-refs**: None

## 4. Architectural Insights

### Task Management via TRAP
The TASK* files reveal the **Super-100 task switching mechanism**:
- `TRAP;DB=@TWAIT;LDTMA` is a **blocking system call** that suspends the current task
- The `LDTMA` (Load Table Memory Address?) suffix suggests TWAIT is a table-lookup dispatch
- Tasks have **static IDs** (1-3) and **dedicated flag addresses** (17700-17702) for synchronization
- The `$TASK n /M` directive assigns task priority/identity at assembly time

### Host Interface Architecture
TEST2.S exposes the **message-passing API**:
- **FGET**: Blocking receive on a specific exchange (R1 = exchange number)
- **FTST**: Non-blocking poll (returns validity in R2)
- **FPUT**: Send to exchange (R2 = datum, exchange from DPX(1))
- **SENDER**: Alternative send path (tests both mechanisms)
- Exchange numbers are **1-based** (initial wait on exchange 1)
- Return status in R2: 0 = valid message, non-zero = error/no message

### COMMON Block Implementation
The SHOOT/SUB files show how **AP Fortran COMMON blocks** are accessed from APAL:
- `$COMMON /name/ vars` declares the layout
- Variables are accessed via **MD addresses** (absolute or relative to COMMON base)
- `$COMIO PASS 1` indicates COMMON I/O pass number (for overlay management?)
- COMMON blocks are **statically allocated** in MD

### S-Pad Parameter Passing
SUBR1's `$ENTRY SUBR1,13.` reveals the **calling convention**:
- The number after the entry name (13) indicates **S-Pad parameter count**
- Parameters are passed in S-Pad registers 0 through N-1
- The SPD (S-Pad Data pointer) can be used for **indexed access** to S-Pad registers
- `LDSPD` loads SPD from S-Pad 0, enabling register-relative addressing

### Status Register Manipulation
SUBR4 demonstrates **direct status register access**:
- `RPSL COUNT; DPX<DB` reads a status location into DPX
- `LPSL COUNT; DB=DPX` writes DPX back to status
- The COUNT label with NOP suggests this is a **memory-mapped status register** at that address
- This is likely the **APSTAT register** or a **task control block field**

### Memory-Mapped I/O
The flag addresses (17700-17702) and the pattern of `LDMA;DB=FLAG1; INC R3;STATMA;MI<DB;DB=SPFN` reveal:
- **Atomic read-modify-write** using the MA (Memory Address) register
- `STATMA` stores the ALU status (MI = minus flag) to memory
- `SPFN` (S-Pad Function?) is used as a memory write control
- Address 17700+ appears to be a **memory-mapped task flag area**

## 5. Design Observations

### Code Reuse Pattern
The TASK* files are **near-identical** except for constants (ID, TIME, FLAG). This suggests:
- A **template-based code generation** approach
- Tasks are parameterized instances of a generic task structure
- The `$TASK n /M` directive likely generates the task control block

### Loop Optimization
SEQV1/SEQV2 use a **decrement-and-test** pattern:
```
DEC R0
DEC# R0        ; Decrement again (sets condition codes)
BNE LOOP       ; Branch if not zero
```
The `DEC#` (decrement with condition code set) followed by `BNE` is an **idiom for counting loops** that avoids an extra compare instruction.

### Parallel Instruction Issue
Several sequences show **parallel execution** (semicolon separator):
```
INC 14
MOV 14,1                       "EXCH DEST
LDSPI 2; DB=MD                 "ELEMENT TO SEND
```
The `LDSPI 2; DB=MD` shows a **load-immediate with data bus source** in one instruction. The AP-120B's **horizontal microcode** allows multiple operations per cycle.

### COMMON Block Access Pattern
SHOOT.S shows the **COMMON access idiom**:
```
LDSPI 13; DB=PUT;              "ELEMENT LIST
 LDMA                          "GET 1ST ELEMENT
```
The `LDSPI 13; DB=PUT` loads S-Pad 13 with the address of PUT, then `LDMA` loads the MA register from that address. This is a **pointer-based access** to COMMON.

### Error Handling
TEST2.S shows a **minimalist error handling** approach:
```
MOV R2,R2               "TEST FOR VALID MESSAGE
BEQ CONT                "YES, THEN CONTINUE
" ERROR!
HALT                    "STOP ON ERROR
```
The `MOV R2,R2` is a **no-op that sets condition codes** (testing if R2 is zero). On error, the AP **halts entirely** rather than attempting recovery.

### Overlay Management
SUB2.S's `CALL APOVLD(3)` suggests:
- AP programs can be **overlaid** (segmented)
- `APOVLD` is a **runtime overlay loader** that loads segment 3
- This is consistent with the Super-100's ability to load AP code from host memory

### Revision Control
The files show a **simple revision scheme**:
- REL A.0 (Aug 79) → REL 1.0 (Nov 79) → REL 3.0 (Jun 79? out of order)
- SHOOT.S (A.0) → SHOOTM.S (1.0) with identical code
- SUBR1.S (A.0) → SUB1.S (1.0) with identical code
- This suggests **parallel development branches** or **version numbering inconsistencies**

### Assembly Directives
The `$COMIO PASS 1` directive in SUB1.S/SUBR1.S is notable:
- It likely controls **COMMON block initialization** (pass 1 = first initialization)
- The `$DATA IT(1) 0` provides **initial values** for COMMON variables
- This is a **higher-level abstraction** than raw MD initialization

### Test Coverage
The test suite covers:
- **Task scheduling** (TASK*): Concurrency, blocking, synchronization
- **Host communication** (TEST2): Send/receive/poll, error handling
- **Data generation** (SEQV*): Vector building
- **Fortran interface** (SHOOT*, SUB*): COMMON access, parameter passing, overlay loading
- **Status manipulation** (SUBR4): Direct register access

This is a **comprehensive validation** of the Super-100/Mini-100 supervisor's key features.

### GLM final

(adv 2s, 40c)

ERROR: HTTP Error 429: Too Many Requests

<details><summary>Cooperative drafts</summary>

#### DS coop

# Structured Analysis of APAL Test Programs and Sequence Vectors

## 1. Subsystem Overview

This group of files constitutes the **test and validation subsystem** for the FPS-100 AP-side supervisor (Super-100/Mini-100). These programs exercise:

- **Task scheduling and inter-task communication** (TASK51.S, TASK52.S, TASK53.S)
- **Host interface message passing** (TEST2.S, SHOOT.S, SHOOTM.S)
- **AP Fortran runtime integration** (SUB2.S, SUBR2.S - AP Fortran stubs)
- **Basic arithmetic and memory operations** (SEQV1.S, SEQV2.S, SUB1.S, SUBR1.S, SUBR3.S, SUBR4.S)

The files demonstrate the supervisor's ability to manage multiple concurrent tasks, exchange messages with the host, and coordinate with AP Fortran-compiled code.

---

## 2. Per-File Purpose

### TASK51.S ($TITLE TASK1)
- **$ENTRY**: TASK1
- **$EXT**: FPUT, TWAIT
- **Purpose**: Task 1 of a multi-task test. Loops indefinitely, waiting for messages via TWAIT, incrementing a flag at address 17700, and echoing via FPUT.
- **AP State**: S-Pad R0-R3, DPX(0-1), MD at FLAG1 (17700), TRAP to TWAIT

### TASK52.S ($TITLE TASK2)
- **$ENTRY**: TASK2
- **$EXT**: FPUT, TWAIT
- **Purpose**: Task 2, identical structure to TASK1 but with ID=2, TIME1=45, FLAG1=17701
- **AP State**: Same as TASK51, different flag address

### TASK53.S ($TITLE TASK3)
- **$ENTRY**: TASK3
- **$EXT**: FPUT, TWAIT
- **Purpose**: Task 3, identical structure with ID=3, TIME1=61, FLAG1=17702
- **AP State**: Same pattern, third flag address

### TEST2.S ($TITLE ECHO)
- **$ENTRY**: ECHO,0
- **$EXT**: FPUT, FGET, FTST, SENDER
- **Purpose**: Host interface test. Waits for message (FGET), then echoes it back (FPUT) and tests alternate path (SENDER). Includes error halt on invalid message.
- **AP State**: S-Pad R1-R5, DPX(0-1), HALT instruction for error

### SEQV1.S ($TITLE SEQV1)
- **$ENTRY**: SEQV1,0
- **$EXT**: None
- **Purpose**: Builds a descending integer vector (31 down to 0) into SARRAY. Uses $INSERT SEQV1.DAT for constants.
- **AP State**: S-Pad R0, MD at SARRAY+31 through SARRAY, DECMA/INC# operations

### SEQV2.S ($TITLE SEQV2)
- **$ENTRY**: SEQV2,0
- **$EXT**: None
- **Purpose**: Builds a descending integer vector (32 down to 1) into SARRAY starting at address 0. Self-contained (no external data file).
- **AP State**: S-Pad R0, MD at SARRAY+32 through SARRAY

### SHOOT.S ($TITLE SHOOT)
- **$ENTRY**: SHOOT,0
- **$EXT**: FPUT
- **$COMMON**: /PUT/ COUNT, W, X, Y, Z (all /I)
- **Purpose**: Sends 5 elements from COMMON block /PUT/ to exchanges 2-6 via FPUT. Test for HASI (Host AP Software Interface).
- **AP State**: S-Pad 13-15, MD from COMMON block, DPX for message data

### SHOOTM.S ($TITLE SHOOT)
- **$ENTRY**: SHOOT,0
- **$EXT**: FPUT
- **$COMMON**: /PUT/ COUNT, W, X, Y, Z (all /I)
- **Purpose**: Identical to SHOOT.S but labeled as REL 1.0, NOV 79 (later revision). Same COMMON block structure.
- **AP State**: Same as SHOOT.S

### SUB1.S ($TITLE SUBR1)
- **$ENTRY**: SUBR1,13.
- **$COMIO**: PASS 1
- **$COMMON**: /PASS/ IT(17.) /I
- **$DATA**: IT(1) 0
- **Purpose**: Stores S-Pad registers 0-12 into COMMON array IT(1..13). Increments a count in IT(0). Tests SPD (S-Pad Data) pointer manipulation.
- **AP State**: S-Pad 0-2, SPD pointer, MD at IT array, DPX for count increment

### SUB2.S (AP Fortran)
- **Purpose**: AP Fortran subroutine SUBR2. Performs integer arithmetic (A=B+C), updates COMMON /PUT/, calls APOVLD(3) and SHOOT. Demonstrates AP Fortran-to-APAL interface.
- **AP State**: Managed by AP Fortran runtime

### SUBR1.S ($TITLE SUBR1)
- **$ENTRY**: SUBR1,13.
- **$COMIO**: PASS 1
- **$COMMON**: /PASS/ IT(17.) /I
- **$DATA**: IT(1) 0
- **Purpose**: Identical to SUB1.S but labeled REL A.0, AUG 79 (earlier revision). Same COMMON block and logic.
- **AP State**: Same as SUB1.S

### SUBR2.S (AP Fortran)
- **Purpose**: AP Fortran subroutine SUBR2. Identical to SUB2.S but labeled REL A.0, AUG 79. Same COMMON /PUT/ and SHOOT call.
- **AP State**: Managed by AP Fortran runtime

### SUBR3.S ($TITLE SUBR3)
- **$ENTRY**: SUBR3,2
- **$EXT**: None
- **Purpose**: Stores S-Pad registers 0 and 1 into MD at address 17700, then stores their sum. Basic memory write test.
- **AP State**: S-Pad 0-1, MD at 17700-17702

### SUBR4.S ($TITLE SUBR4)
- **$ENTRY**: SUBR4,0
- **$EXT**: None
- **Purpose**: Reads/writes a "COUNT" location using RPSL/LPSL (Read/Load Program Status Long). Demonstrates PSW manipulation. Increments a counter.
- **AP State**: PSW (Program Status Word), DPX for temporary storage

---

## 3. Key Routines

### TASK1/TASK2/TASK3 (TASK51.S, TASK52.S, TASK53.S)

**Calling Convention**: Entry point only (no arguments). Runs as a supervisor task.

**Side Effects**:
- S-Pad: R0 cleared, R1 = task ID, R2 = run count, R3 = flag increment
- DPX(0) = TIME1 (wait time), DPX(1) = EXDAT1 (message exchange)
- MD: FLAG1/FLAG2/FLAG3 (17700-17702) incremented
- TRAP to TWAIT (suspends task)
- JSR to FPUT (sends message)

**Cross-References**: FPUT, TWAIT (external)

### ECHO (TEST2.S)

**Calling Convention**: Entry point only. No arguments.

**Side Effects**:
- S-Pad: R1=1 for FGET, R2 tested for validity, R3 holds echoed datum
- DPX(1) set to DPX for SENDER call
- HALT on error

**Cross-References**: FPUT, FGET, FTST, SENDER (external)

### SEQV1/SEQV2 (SEQV1.S, SEQV2.S)

**Calling Convention**: Entry point only. No arguments. Returns via RETURN.

**Side Effects**:
- S-Pad: R0 decremented from 31/32 to 0
- MD: SARRAY[0..31] or SARRAY[0..32] written with descending values
- DECMA used for auto-decrementing memory address

**Cross-References**: None

### SHOOT (SHOOT.S, SHOOTM.S)

**Calling Convention**: Entry point only. Uses COMMON /PUT/.

**Side Effects**:
- S-Pad: 13 = pointer to COMMON, 14 = exchange number (2-6), 15 = loop counter (5)
- MD: Reads from COMMON block /PUT/
- JSR to FPUT for each element

**Cross-References**: FPUT (external), /PUT/ COMMON

### SUBR1 (SUB1.S, SUBR1.S)

**Calling Convention**: Entry point with 13 S-Pad arguments. Returns via RETURN.

**Side Effects**:
- S-Pad: 0-2 used as scratch, SPD pointer cycles through 3..15
- MD: IT(0) = count, IT(1..13) = S-Pad values 0..12
- DPX used for count increment

**Cross-References**: /PASS/ COMMON

### SUBR3 (SUBR3.S)

**Calling Convention**: Entry point with 2 arguments (S-Pad 0,1). Returns via RETURN.

**Side Effects**:
- MD: 17700 = SP0, 17701 = SP1, 17702 = SP0+SP1
- S-Pad: 0,1 preserved

**Cross-References**: None

### SUBR4 (SUBR4.S)

**Calling Convention**: Entry point with 0 arguments. Returns via RETURN.

**Side Effects**:
- PSW: COUNT location read and written via RPSL/LPSL
- DPX: temporary storage for count value
- S-Pad: 0 used for DPX transfer

**Cross-References**: None

---

## 4. Architectural Insights

### Task Management via TRAP/TWAIT
The TASK*.S files reveal how the supervisor implements **cooperative multitasking**. The pattern:
```
DPX(X1)<EXDAT1          ; Set exchange for message
DPX(X0)<TIME1           ; Set timeout
TRAP;DB=@TWAIT;LDTMA    ; Suspend until message arrives
```
The TRAP instruction with LDTMA (Load Table Memory Address) invokes the TWAIT supervisor call, which suspends the task until a message arrives on the specified exchange. This is the AP-side equivalent of a blocking receive.

### Message Exchange Addressing
The EXDAT1 constant (likely defined in FHOSTC) and exchange numbers 2-6 in SHOOT.S demonstrate the **host-AP message passing system**. Exchanges are numbered channels for bidirectional communication.

### Flag-Based Synchronization
Tasks increment flags at addresses 17700-17702. These are likely **memory-mapped I/O locations** or **shared memory** visible to the host, allowing the host to monitor task progress.

### SPD (S-Pad Data) Pointer Manipulation
SUB1.S/SUBR1.S show sophisticated use of the SPD pointer:
```
LDSPI 0; DB=3; LDSPD    ; Initialize SPD to point to SP3
...
INC 0; DB=SPFN; LDSPD   ; Increment SPD pointer
```
This allows sequential access to S-Pad registers 3-15, which is not directly possible with register addressing.

### PSW Manipulation via RPSL/LPSL
SUBR4.S demonstrates direct Program Status Word manipulation:
```
RPSL COUNT; DPX<DB      ; Read PSW into DPX
LPSL COUNT; DB=DPX;     ; Write DPX back to PSW
```
The COUNT label is a NOP placeholder, suggesting this is a **relative offset** into the PSW for a specific status bit or counter field.

### AP Fortran Integration
SUB2.S/SUBR2.S show AP Fortran calling APAL routines:
```
CALL APOVLD(3)           ; AP overlay load
CALL SHOOT               ; Call APAL routine
```
The COMMON /PUT/ block is shared between AP Fortran and APAL, demonstrating the **mixed-language programming model**.

---

## 5. Design Observations

### Compact Loop Idioms
The SEQV*.S files use a clever loop termination:
```
DEC R0                  ; Decrement counter
DEC# R0                 ; Decrement again (sets flags)
BNE LOOP                ; Branch if not zero
```
The `DEC#` (decrement with test) avoids a separate compare instruction, saving one word per iteration.

### Parallel Instruction Execution
Multiple instructions per line indicate **parallel execution**:
```
INC R3;STATMA;MI<DB;DB=SPFN  ; Increment, store, set flags
MOV R0,R0;DECMA;MI<DB;       ; Move (NOP), decrement MA, store
```
The semicolon separates operations that execute in the same cycle, exploiting the AP's horizontal microarchitecture.

### Self-Modifying Code Pattern
SUBR4.S uses a NOP placeholder (COUNT:) that is effectively a **self-modifying code** target. The RPSL/LPSL instructions read/write the PSW at that location, treating it as a data word rather than an instruction.

### COMMON Block Conventions
The `$COMMON` directive with `/I` suffix indicates **integer** data type. The `$COMIO` directive in SUB1.S specifies I/O pass number for COMMON block initialization.

### Error Handling via HALT
TEST2.S uses HALT for error conditions, which stops the AP processor. This is appropriate for test code but would be replaced by error recovery in production.

### Register Usage Conventions
- R0-R3: General purpose, often used as loop counters
- R13-R15: Used for COMMON block pointers and loop control (SHOOT.S)
- DPX(0-1): Message data and timeouts
- SPD: Pointer for sequential S-Pad access

### Task ID Encoding
Tasks use S-Pad R1 to hold their ID, which is passed to TWAIT for message routing. This suggests the supervisor uses task IDs for message demultiplexing.

### Revision History
The files show two revision levels:
- REL A.0, AUG 79 (earlier): SUBR1.S, SUBR2.S, SHOOT.S
- REL 1.0, NOV 79 (later): SUB1.S, SUB2.S, SHOOTM.S, SUBR3.S, SUBR4.S
- REL 3.0, JUN 79: TASK*.S (different numbering scheme)

The later revisions maintain identical logic but may have different COMMON block layouts or interface conventions.

#### GLM coop

ERROR: HTTP Error 429: Too Many Requests

</details>


