require('./bootstrap-datepicker')
require('./bootstrap-timepicker')

# Exports a single task
class AutoComplete
    

    constructor : (container, editor) ->
        
        @container  = container
        @editor     = editor
        @tTags       = [] # types of tags
        @tTagsDiv    = document.createElement('DIV')
        @contacts    = [] # items of contact
        @contactsDiv = document.createElement('DIV')
        @reminderDiv = document.createElement('DIV')
        @htagDiv     = document.createElement('DIV')
        reminderHTML = 
        """
            <div class="reminder-title">Add a reminder</div>
            <div class="date" data-date="12-02-2012" data-date-format="dd-mm-yyyy">
                <div class="reminder-input">
                    <input class="datepicker-input" size="16" type="text" value="12-02-2012"/>
                    <input id="timepicker" data-template="modal" data-minute-step="1" data-modal-backdrop="true" type="text"/>
                </div>
            </div>
        """
        @reminderDiv.innerHTML = reminderHTML
        @datePick = $(@reminderDiv.lastChild).datepicker()
        @datePick.show()
        @datePick.on('changeDate', (ev) =>
            nd = ev.date
            date = @_currentDate
            date.setDate(nd.getDate())
            date.setMonth(nd.getMonth())
            date.setFullYear(nd.getFullYear())
        )


        @timePick = $(@reminderDiv.childNodes[2].firstElementChild.lastElementChild)
        @timePick.timepicker(
            minuteStep   : 1
            template     : 'modal'
            showSeconds  : true
            showMeridian : false
        )
        # .timepicker().on('changeTime.timepicker', (e) ->
        #     console.log e.time
        #     t = e.time
        #     date = @_currentDate
        #     date.setHours(t.getDate())
        #     date.setMinutes(t.getMonth())
        #     date.setSeconds(t.getFullYear())
        # )

        @regexStore = {}
        @isVisible  = false

        auto  = document.createElement('div')
        auto.id = 'CNE_autocomplete'
        auto.className = 'CNE_autocomplete'
        auto.setAttribute('contenteditable','false')
        auto.addEventListener 'keypress', (e) =>
            if e.keyCode == 13 # return
                @_validateUrlPopover()
                e.stopPropagation()
            else if e.keyCode == 27 # esc
                @_cancelUrlPopover(false)
            return false
        auto.appendChild(@tTagsDiv)
        @el = auto

        # default mode = contact : will be overriden when show is called
        @_currentMode = 'contact'
        auto.appendChild(@contactsDiv)

        @setItems( 'tTags', [
            {text:'contact'         , type:'ttag', mention:' (@)' }
            {text:'reminder'        , type:'ttag', mention:' (@@)'}
            {text:'todo'            , type:'ttag'                 }
            {text:'tag'             , type:'ttag', mention:' (#)' }
            ])

        @setItems( 'contact', [
            {text:'Frank @Rousseau' , type:'contact'             }
            {text:'Lucas Toulouse'  , type:'contact'             }
            {text:'Maxence Cote'    , type:'contact'             }
            {text:'Joseph Silvestre', type:'contact'             }
            {text:'Romain Foucault' , type:'contact'             }
            {text:'Zoé Bellot'      , type:'contact'             }
            ])

        @setItems( 'htag', [
            {text:'Carte'              , type:'htag'}
            {text:'Factures'           , type:'htag'}
            {text:'Javascript'         , type:'htag'}
            {text:'Pérou 2012'         , type:'htag'}
            {text:'Présentation LyonJS', type:'htag'}
            {text:'Recettes cuisine'   , type:'htag'}
            ])

        return this


    setItems : (type, items) ->
        # console.log ' setItems', items, type
        switch type
            when 'tTags'
                @tTags = items
                lines = @tTagsDiv
            when 'contact'
                @contacts = items
                lines = @contactsDiv
            when 'htag'
                @htags = items
                lines = @htagDiv
        for it in items
            lines.appendChild(@_createLine(it))

        return true


    _createLine : (item) ->
        # console.log '_createLine', item

        line = document.createElement('LI')

        type = item.type
        switch type
            when 'ttag'
                line.className = 'SUGG_line_ttag'
            when 'contact'
                line.className = 'SUGG_line_contact'
            when 'htag'
                line.className = 'SUGG_line_htag'
        # if line.childNodes.length != 0
        #     line.innerHTML = ''

        t = item.text.split('')
        for c in t
            span = document.createElement('SPAN')
            span.textContent = c
            line.appendChild(span)

        if item.mention
            span = document.createElement('SPAN')
            span.textContent = item.mention
            span.className = 'SUGG_mention'
            line.appendChild(span)

        line.item = item
        item.line = line

        return line


    ###*
     * Show the suggestion list
     * @param  {Object} currentSel The editor current selection
     * @param  {String} typedTxt   The string typed by the user (hotstring)
     * @param  {[type]} edLineDiv  The editor line div where the user is typing
    ###
    show : (currentSel,typedTxt,edLineDiv) ->
        # modes = ['todo','contact','event','reminder','tag']
        @_currentEdLineDiv = edLineDiv if edLineDiv
        # @_setModes(modes)
        @_updateDisp(typedTxt)
        @_position(currentSel) if currentSel
        @container.appendChild(@el)
        @isVisible = true

        # add event listener to detect a click outside of the popover
        @container.addEventListener('mousedown',@_detectMousedownAuto)
        @container.addEventListener('mouseup',@_detectMouseupAuto)

                
    setModes : (modes) ->
        @_modes = modes
        for ttag in @tTags
            ttag.isInMode = false
            for m in modes
                if ttag.text == m
                    ttag.isInMode = true
                    break
            
        if modes[0] == @_currentMode
            return

        switch modes[0]
            when 'contact'
                @el.removeChild(@el.lastChild)
                @el.appendChild(@contactsDiv)
                @_currentMode = 'contact'
            when 'tag'
                @el.removeChild(@el.lastChild)
                @el.appendChild(@htagDiv)
                @_currentMode = 'htag'
            when 'reminder'
                @el.removeChild(@el.lastChild)
                now = new Date()
                @_currentDate = now
                @_initialDate = new Date()
                @datePick.datepicker('setValue', now)
                @timePick.timepicker('setTime', now.getHours()+':'+now.getMinutes()+':'+now.getSeconds())
                @el.appendChild(@reminderDiv)
                @_currentMode = 'reminder'
        

    update : (typedTxt) ->
        if !@isVisible
            return
        @_updateDisp(typedTxt)


    _updateDisp : (typedTxt) ->

        # check the ttags to show
        for ttag in @tTags
            if ttag.isInMode && @_shouldDisp(ttag,typedTxt)
                ttag.line.style.display = 'block'
            else 
                ttag.line.style.display = 'none'

        switch @_currentMode
            when 'contact'
                items = @contacts
            when 'htag'
                items = @htags
            when 'reminder'
                reg1 = /(\d*)h(\d*)mn/i
                reg2 = /(\d*)h/i
                txt = typedTxt.slice(2)
                resReg1 = reg1.exec(txt)
                resReg2 = reg2.exec(txt)

                console.log txt
                console.log resReg1
                if resReg1
                    dh  = parseInt(resReg1[1]) * 3600000
                    dmn = parseInt(resReg1[2]) * 60000
                else if resReg2
                    dh = parseInt(resReg2[1])  * 3600000
                    dmn  = 0
                if resReg1 or resReg2
                    @_currentDate.setTime(@_initialDate.getTime() + dh + dmn)
                    now = @_currentDate
                    @datePick.datepicker('setValue', now)
                    @timePick.timepicker('setTime', now.getHours()+':'+now.getMinutes()+':'+now.getSeconds())
                return

        # check the items to show
        for it in items
            if @_shouldDisp(it,typedTxt)
                it.line.style.display = 'block'
            else 
                it.line.style.display = 'none'

        # sort items to show
        @_sortItems()

        return true


    _position : (currentSel) ->
        span = document.createElement('SPAN')
        targetRange = currentSel.theoricalRange
        targetRange.insertNode(span)
        @el.style.left = span.offsetLeft + 'px'
        @el.style.top = span.offsetTop + 17 + 'px'
        parent = span.parentNode
        span.parentNode.removeChild(span)
        parent.normalize()
        currentSel.range.collapse(true)
        return true


    _sortItems : () ->



    _addLine : (item) ->
        line = document.createElement('LI')
        # line.className = 'SUGG_line'
        @_updateLine(line,item)
        # line.addEventListener('click',@_clickCB)
        @el.appendChild(line)
        return line


    _updateLine : (line,item, typedTxt) ->
        console.log '_updateLine'
        type = item.type
        switch type
            when 'tag'
                line.className = 'SUGG_line_tag'
            when 'contact'
                line.className = 'SUGG_line_contact'
        if line.childNodes.length != 0
            line.innerHTML = ''

        t = item.text.split('')
        for c in t
            span = document.createElement('SPAN')
            span.textContent = c
            line.appendChild(span)

        if item.mention
            span = document.createElement('SPAN')
            span.textContent = item.mention
            span.className = 'mention'
            line.appendChild(span)

        line.item = item


    _selectLine : () ->
        if @_selectedLine
            @_selectedLine.classList.add('SUGG_selected')


    _unSelectLine : () ->
        if @_selectedLine
            @_selectedLine.classList.remove('SUGG_selected')


    _removeLine : (line)->
        @el.removeChild(line)


    hide : () ->
        if !@isVisible
            return false
        @container.removeChild(@el)
        @_currentEdLineDiv = null
        @container.removeEventListener('mousedown',@_detectMousedownAuto)
        @container.removeEventListener('mouseup',@_detectMouseupAuto)
        switch @_currentMode
            when 'contact'
                if @_selectedLine
                    @_unSelectLine()
                    item = @_selectedLine.item
                else
                    item = null
                    @_selectedLine = null
            when 'htag'
                if @_selectedLine && @_selectedLine.item.type == 'htag'
                    @_unSelectLine()
                    item = @_selectedLine.item
                else
                    item = null
                    @_selectedLine = null
            when 'reminder'
                date = @_currentDate
                item = text:date, type:'reminder'
                
            
        
        @isVisible = false
        return item


    _shouldDisp : (item,typedTxt) ->
        if @regexStore[typedTxt]
            reg = @regexStore[typedTxt]
        else
            reg = new RegExp(typedTxt.split('').join('[\\w ]*').replace('\W','').replace('\+','\\+'), 'i')
            @regexStore[typedTxt] = reg
        if item.text.match(reg)
            typedCar = typedTxt.toLowerCase().split('')
            c = typedCar.shift()
            spans = item.line.childNodes
            i = 0
            l = spans.length 
            if item.line.lastChild.className == 'SUGG_mention'
                l -= 1
            while i < l
                s = spans[i]
                if s.textContent.toLowerCase() == c
                    s.className = 'b'
                    c = typedCar.shift()
                    if c
                        i += 1
                    else
                        break
                else
                    s.className = ''
                    i += 1
            return true
        else
            return false


    up : () ->

        if !@_selectedLine
            @_selectedLine = @el.lastChild.lastChild

        else
            @_unSelectLine()
            prev = @_selectedLine.previousSibling
            if prev
                @_selectedLine = prev
            else
                if @_selectedLine.item.type == 'ttag'
                    @_selectedLine = @el.lastChild.lastChild
                else
                    @_selectedLine = @el.firstChild.lastChild

        if @_selectedLine.style.display == 'none'
            @up()
        else
            @_selectLine()

        return true


    down : () ->
        if !@_selectedLine
            @_selectedLine = @el.firstChild.firstChild

        else
            @_unSelectLine()
            next = @_selectedLine.nextSibling
            if next
                @_selectedLine = next
            else
                if @_selectedLine.item.type == 'ttag'
                    @_selectedLine = @el.lastChild.firstChild
                else
                    @_selectedLine = @el.firstChild.firstChild

        if @_selectedLine.style.display == 'none'
            @down()
        else
            @_selectLine()


    val : () ->
        return @_selectedLine.item


    isInTTags : (text) ->
        for tag in @tTags
            if text == tag.text
                return tag
        return false


    _detectMousedownAuto : (e) =>
        console.log '== mousedown'
        e.preventDefault()


    _detectMouseupAuto : (e) =>
        console.log '== mouseup'
        # detect if click is in the list or out
        isOut =     e.target != @el                                    \
                and $(e.target).parents('#CNE_autocomplete').length == 0
        if isOut
            @hide()
        else
            if @_currentMode == 'reminder'
                return
            selectedLine = e.target
            while selectedLine && selectedLine.tagName != ('LI')
                selectedLine = selectedLine.parentElement
            if selectedLine
                @editor._doHotStringAction(selectedLine.item,@_currentEdLineDiv)
                @hide()
            else
                @hide()

exports.AutoComplete = AutoComplete