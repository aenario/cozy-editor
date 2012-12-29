class exports.AutoTest


    ###*
     * Checks whether the lines and the editor controler are consistent.
     * What is checked :
     *    <> each elt of lines corresponds to a DIV ------------------ (OK)
     *    <> each DIV has a matching elt in lines -------------------- (OK)
     *    <> type and depth are coherent ----------------------------- (OK)
     *    <> linePrev and LineNext are linked to the correct DIV ----- (OK)
     *    <> hierarchy of lines and indentation are okay ------------- (OK)
     *    <> a DIV contains at least 2 nodes  ------------------------ (OK)
     *    <> last node of a DIV is a BR  ----------------------------- (OK)
     *    <> two successive SPAN can't have the same class ----------- (OK)
     *    <> empty SPAN are really empty (<span></span>) ------------- (huh?)
     *    <> a note must  have at least one line --------------------- (todo)
     * BUG? un Tu-6 qui suit un Th-1 n'est pas détecté
     * [checkLines description]
     * @param  {CNeditor} editor The editor instance to validate
     * @return {boolean}        True if editor is valid, false otherwise
    ###
    checkLines : (editor) ->
        # init
        console.log 'Detecting incoherences...'
        @editor    = editor
        @divLines$ = $(editor.editorBody$[0].children[1])
        
        # 1-Is there a line object corresponding to each DIV ?
        try
            @checkEachDivRefersALine()
        catch error
            return false

        # 2- Tree construction
        # We represent the lines architecture with a tree to depth-first
        # explore it. The virtual root is at depth 0 and its sons are the titles
        # located at depth 1.
        #     Internal nodes = titles (Th, Tu, To)
        #     Leaves         = lines  (Lh, Lu, Lo)
        # An internal node T-n can only have T-(n+1) or L-n children
        # A To (resp Tu, Th) can only have Lo (resp Lu, Lh) lines
        # A To/Tu can't be the father of a Th
        try    
            root = @buildTree()
        catch error    
            return false

        # Tree validation
        try    
            @recVerif(root)
        catch error
            return false

        # everything went well !
        console.log 'editor structure is valid'
        return true


    #     Utility functions
    # 
    # Defines what type of children a node can have
    # only useful for the structure's verification
    possibleSon : {
        'Th': (name) ->
            return name=='Lh' || name=='Th' || name=='To' || name=='Tu'
        'Tu': (name) ->
            return name=='Lu' || name=='To' || name=='Tu'
        'To': (name) ->
            return name=='Lo' || name=='To' || name=='Tu'
        'Lh': (name) ->
            return false
        'Lu': (name) ->
            return false
        'Lo': (name) ->
            return false
        'root': (name) ->
            return name=='Th' || name=='Tu' || name=='To' || 
                   name=='Lh' || name=='Lu'
        }

    ###*
     * Print error info in the console and throws an error
     * @param  {line} line the line where there is an error
     * @param  {string} txt  a text to display
    ###
    logErr : (line,txt) ->
        msg1 = "ERROR: invalid line #{line.lineID}"
        msg2 = "  => #{line.lineType}-#{line.lineDepthAbs} " + txt
        console.log ''
        console.log msg1
        console.log line.line$[0]
        console.log msg2
        throw new Error(msg1 + '\n' + msg2)

    # 
    ###*
     * Returns whether the DIV is a line or a title (L or T)
     * @param  {string} name The type of line to check
     * @return {string} L or T
    ###
    nodeType : (name) ->
        if name=='Lh' || name=='Lu' || name=='Lo'
            return 'L'
        else if name=='Th' || name=='Tu' || name=='To'
            return 'T'
        else
            throw new Error('incorrect node type : ' + name)


    ###*
     * Walk threw the tree to check the structure.
     * Tests :
     *     * 1- all sons of a line has the same type
     *     * the type of the sons of a line is valid (Tx -> Lx)
     *     * the indentation increase at most of 1 (no constraint on depth
     *       decrease)
     *     * 
     * @param  {[type]} node [description]
     * @return {[type]}      [description]
    ###
    recVerif : (node) ->    
        if node.sons.length > 0
            sonsType = node.sons[0].line.lineType


            for child in node.sons
                # Hierarchy verification
                if ! @possibleSon[node.line.lineType](child.line.lineType)
                    txt = "a line type #{node.line.lineType} can't have a child of type #{sonsType}"
                    @logErr(node.line,txt)

                # # 1- all sons of a line has the same type
                # if sonsType != child.line.lineType
                #     txt =  'all sons don\'t have the same ' \
                #          + "type #{sonsType} != #{child.line.lineType})"
                #     @logErr(node.line,txt)

                    
                # Depth verification
                if @nodeType(child.line.lineType) == 'T'
                    if node.line.lineDepthAbs+1 != child.line.lineDepthAbs
                        txt = 'indentation issue'
                        @logErr(node.line,txt)
                    @recVerif(child)
                else if @nodeType(child.line.lineType) == 'L'
                    if node.line.lineDepthAbs != child.line.lineDepthAbs
                        txt = 'indentation issue'
                        @logErr(node.line,txt)
                        
        return true


    # A node object is a ptr to a line and an array of sons
    createNode : (line, sons)->
        line: line
        sons: sons


    checkElement: (elmt, line) ->
        if elmt.nodeName == 'SPAN' or elmt.nodeName == 'A'
            @checkTextNodes elmt, line
        else
            @logErr(line,"element #{elmt.nodeName} not expected in a line")


    ###*
     * Check that an element has at most only one child node which must be
     * a textNode.
     * Rq : having no text node is not a problem, normalization of the selection
     * will add it before any insertion.
     * @param  {element} elmt the element to check
     * @param  {line} line line where the element comes from
    ###
    checkTextNodes: (elmt, line) ->
        if elmt.childNodes.length > 1
            @logErr(line,"a #{elmt.nodeName} should have only 1 child node")
        else if elmt.childNodes.length != 0 && elmt.childNodes[0].nodeName != '#text'
            @logErr(line,"element #{elmt.nodeName} should not have 
                a #{elmt.childNodes[0].nodeName} as node child")


    checkLineStructure : (line) ->
        type  = @nodeType(line.lineType)
        depth = line.lineDepthAbs
        
        # 1- check the line has a corresponding element
        lineEl = @divLines$.children('#'+line.lineID)[0]
        if lineEl == null
            txt = 'has no matching DIV'
            @logErr(line,txt)
        
        # 2- a DIV contains a sequence of SPAN A and IMG ended by a BR ----(OK)
        children = [].slice.call(lineEl.childNodes)
        # rq : el.childNodes is not an array, it's a nodeList...
        
        # 2- the main DIV of a line has at least 2 nodes (span & br at least)
        if children == null or children.length < 2
            txt = 'line elements are missing'
            @logErr(line,txt)

        # 3- last node must be a BR
        lastChild = children.pop()
        if lastChild.nodeName != 'BR'
            txt = 'must end with BR'
            @logErr(line,txt)


        lastClass = undefined
        for child in children
            # 4- two successive SPAN can't have the same class -------------(OK)
            if child.nodeName == 'SPAN'
                childClass = child.getAttribute('class')
                if childClass? && lastClass == child.getAttribute('class')
                    txt = "two consecutive SPAN with same 
                          class #{lastClass}"
                    @logErr(line,txt)
                else
                    lastClass = childClass
                @checkElement(child, line)
            else if child.nodeName == 'A'
                lastClass = undefined
            else if child.nodeName == 'IMG'
                lastClass = undefined
            else
                txt = "invalid element in a line (#{child.nodeName})"
                @logErr(line,txt)


    buildTree : () ->
        # We are going to represent the DIVs with a tree, hence we need to 
        # create a virtual root (right before the first line).
        rootLine =
            lineType: 'root'
            lineID: 'CNID_0'
            lineNext: @editor._lines['CNID_1'] # should be _firstLine instead
            linePrev: null
            lineDepthAbs: 0
        root = @createNode(rootLine, [])
        
        # Array of nodes: the n-th element is the last depth-n ancestor met
        @myAncestor = [root]
        
        # Elements of the lines list
        nextLine = rootLine.lineNext
        
        # Reads all the way through lines and tests their structure's legacy
        # While doing this, it also builds a tree from the DIVs list by
        # appending the property ".sons" to every line that is a non-empty title
        # It will be easier to check the remaining properties with a tree
        while nextLine != null
            try 
                @checkLineStructure nextLine
            catch error
                return
                    
            # Then we add it to the tree
            @addLine
            newNode = @createNode(nextLine, [])
            type    = @nodeType(nextLine.lineType)
            depth   = nextLine.lineDepthAbs
            if type == 'T'       # internal node
                # updates the ancestors
                if depth > @myAncestor.length
                    txt = 'indentation issue'
                    @logErr(nextLine,txt)
                    return
                else if depth == @myAncestor.length
                    @myAncestor.push(newNode)
                else
                    @myAncestor[depth] = newNode
                
                # adds title to the tree
                if @myAncestor[depth-1] == null
                    txt = 'indentation issue'
                    @logErr(nextLine,txt)
                    return
                else
                    @myAncestor[depth-1].sons.push(newNode)
                
            else if type == 'L'  # leaf
                # adds line to the tree
                if depth >= @myAncestor.length
                    txt = 'indentation issue'
                    @logErr(nextLine,txt)
                    return
                else
                    @myAncestor[depth+1] = null
                    
                if @myAncestor[depth] == null
                    txt = 'indentation issue'
                    @logErr(nextLine,txt)
                    return
                else
                    @myAncestor[depth].sons.push(newNode)
            # goes to the next node
            nextLine = nextLine.lineNext

        return root



    checkEachDivRefersALine : () ->
        objDiv = @divLines$.children('div')
        objDiv.each (i,div) =>
            myId = div.id
            if /CNID_[0-9]+/.test myId
                if ! @editor._lines[myId]?
                    txt = 'div\'s id has no corresponding line ' + myId
                    @logErr(null,txt)
            else
                txt = 'wrong line id format : ' + myId
                @logErr(null,txt)




