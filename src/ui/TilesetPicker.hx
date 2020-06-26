package ui;

class TilesetPicker {
	var jDoc(get,never) : js.jquery.JQuery; inline function get_jDoc() return new J(js.Browser.document);

	var jPicker : js.jquery.JQuery;
	var jWrapper : js.jquery.JQuery;
	var jImg : js.jquery.JQuery;

	var tool : tool.TileTool;
	var zoom = 3.0;
	var jCursors : js.jquery.JQuery;
	var jSelections : js.jquery.JQuery;
	var jShadows : js.jquery.JQuery;

	var dragStart : Null<{ bt:Int, pageX:Float, pageY:Float }>;

	var scrollX(get,set) : Float;
	var scrollY(get,set) : Float;

	public function new(target:js.jquery.JQuery, tool:tool.TileTool) {
		this.tool = tool;

		// Create picker elements
		jPicker = new J('<div class="tilesetPicker"/>');
		jPicker.appendTo(target);

		jWrapper = new J('<div class="wrapper"/>');
		jWrapper.appendTo(jPicker);
		jWrapper.css("zoom",zoom);

		jShadows = new J('<div class="shadows"/>');
		jShadows.prependTo(jWrapper);

		jCursors = new J('<div class="cursorsWrapper"/>');
		jCursors.prependTo(jWrapper);

		jSelections = new J('<div class="selectionsWrapper"/>');
		jSelections.prependTo(jWrapper);

		jImg = new J( tool.curTilesetDef.createAtlasHtmlImage() );
		jImg.appendTo(jWrapper);
		jImg.addClass("atlas");
		jImg.css("min-width",tool.curTilesetDef.pxWid); // needed because base64 img rendering is async
		jImg.css("min-height",tool.curTilesetDef.pxHei);

		// Init events
		jPicker.mousedown( function(ev) {
			ev.preventDefault();
			onPickerMouseDown(ev);
			jDoc
				.off(".pickerEvent")
				.on("mouseup.pickerEvent", onDocMouseUp)
				.on("mousemove.pickerEvent", onDocMouseMove);
		});

		jPicker.mousemove( onPickerMouseMove );

		scrollX = 0;
		scrollY = 0;
		renderSelection();

		updateShadows();
		// N.debug(jPicker.innerWidth()+"x"+jPicker.innerHeight());
	}

	inline function get_scrollX() {
		return jPicker.scrollLeft();
	}
	inline function set_scrollX(v:Float) {
		jPicker.scrollLeft(v);
		return v;
	}

	inline function get_scrollY() {
		return jPicker.scrollTop();
	}
	inline function set_scrollY(v:Float) {
		jPicker.scrollTop(v);
		return v;
	}

	inline function pageXtoLocal(v:Float) return M.round( ( v - jPicker.offset().left + scrollX ) / zoom );
	inline function pageYtoLocal(v:Float) return M.round( ( v - jPicker.offset().top + scrollY ) / zoom );

	function renderSelection() {
		jSelections.empty();

		for(tileId in tool.getSelectedValue())
			jSelections.append( createCursor(tileId,"selection") );
	}


	function createCursor(tileId:Int, ?subClass:String, ?cWid:Int, ?cHei:Int) {
		var x = tool.curTilesetDef.getTileSourceX(tileId);
		var y = tool.curTilesetDef.getTileSourceY(tileId);

		var e = new J('<div class="tileCursor"/>');
		if( subClass!=null )
			e.addClass(subClass);

		e.css("left", x+"px");
		e.css("top", y+"px");
		var grid = tool.curTilesetDef.tileGridSize;
		e.css("width", ( cWid!=null ? cWid*grid : tool.curTilesetDef.tileGridSize )+"px");
		e.css("height", ( cHei!=null ? cHei*grid : tool.curTilesetDef.tileGridSize )+"px");

		return e;
	}



	var _lastRect = null;
	function updateCursor(pageX:Float, pageY:Float, force=false) {
		if( isScrolling() || Client.ME.isKeyDown(K.SPACE) ) {
			jCursors.hide();
			return;
		}

		Client.ME.debug(pageX+","+pageY+" => "+pageXtoLocal(pageX)+","+pageYtoLocal(pageY));
		Client.ME.debug("scroll="+scrollX+","+scrollY, true);
		Client.ME.debug("pickerSize="+jPicker.innerWidth()+"x"+jPicker.innerHeight(), true);
		Client.ME.debug("img="+jImg.innerWidth()+"x"+jImg.innerHeight(), true);

		var r = getCursorRect(pageX, pageY);

		// Avoid re-render if it's the same rect
		if( !force && _lastRect!=null && r.cx==_lastRect.cx && r.cy==_lastRect.cy && r.wid==_lastRect.wid && r.hei==_lastRect.hei )
			return;

		var tileId = tool.curTilesetDef.getTileId(r.cx,r.cy);
		jCursors.empty();
		jCursors.show();

		var saved = tool.curTilesetDef.getSavedSelectionFor(tileId);
		if( saved==null )
			jCursors.append( createCursor(tileId, r.wid, r.hei) );
		else {
			// Saved-selection rollover
			for(tid in saved)
				jCursors.append( createCursor(tid) );
		}

		_lastRect = r;
	}

	function scroll(newPageX:Float, newPageY:Float) {
		var spd = 1.;

		scrollX -= ( newPageX - dragStart.pageX ) * spd;
		dragStart.pageX = newPageX;

		scrollY -= ( newPageY - dragStart.pageY ) * spd;
		dragStart.pageY = newPageY;

		updateShadows();
	}

	function updateShadows() {
		var shadows = [];
		var col = "rgba(0, 0, 0, 0.4)";
		var dist = "8px";
		var blur = "2px";

		if( scrollX>0 )
			shadows.push('$dist 0px $blur $col inset');

		if( scrollX < jImg.innerWidth()*zoom-jPicker.innerWidth() )
			shadows.push('-$dist 0px $blur $col inset');

		if( scrollY>0 )
			shadows.push('0px $dist $blur $col inset');

		if( scrollY < jImg.innerHeight()*zoom-jPicker.innerHeight() )
			shadows.push('0px -$dist $blur $col inset');

		if( shadows.length>0 ) {
			jShadows.css("margin-left", scrollX/zoom-1); // 1 is because of the padding
			jShadows.css("margin-top", scrollY/zoom-1);
			shadows.push('0px 0px 4px black');
			jShadows.css("box-shadow", shadows.join(","));
		}
		else
			jShadows.css("box-shadow", "none");
	}

	inline function isScrolling() {
		return dragStart!=null && ( dragStart.bt==1 || Client.ME.isKeyDown(K.SPACE) );
	}

	function onDocMouseMove(ev:js.jquery.Event) {
		updateCursor(ev.pageX, ev.pageY);

		if( isScrolling() )
			scroll(ev.pageX, ev.pageY);
	}

	function onDocMouseUp(ev:js.jquery.Event) {
		jDoc.off(".pickerEvent");

		if( dragStart!=null ) {
			// Apply selection
			if( !isScrolling() ) {
				var r = getCursorRect(ev.pageX, ev.pageY);
				if( r.wid==1 && r.hei==1 )
					onSelect([ tool.curTilesetDef.getTileId(r.cx,r.cy) ]);
				else {
					var tileIds = [];
					for(cx in r.cx...r.cx+r.wid)
					for(cy in r.cy...r.cy+r.hei)
						tileIds.push( tool.curTilesetDef.getTileId(cx,cy) );
					onSelect(tileIds);
				}
			}
		}

		dragStart = null;
		updateCursor(ev.pageX, ev.pageY, true);
	}

	function onSelect(sel:Array<Int>) {
		// Auto-pick saved selection
		if( sel.length==1 && tool.curTilesetDef.hasSavedSelectionFor(sel[0]) ) {
			// Check if the saved selection isn't already picked. If so, just pick the sub-tile
			var cur = tool.getSelectedValue();
			var saved = tool.curTilesetDef.getSavedSelectionFor( sel[0] ).copy();
			var same = true;
			var i = 0;
			while( i<saved.length ) {
				if( cur[i]!=saved[i] )
					same = false;
				i++;
			}
			if( !same )
				sel = saved;
		}

		var cur = tool.getSelectedValue();
		if( !Client.ME.isShiftDown() && !Client.ME.isCtrlDown() )
			tool.selectValue(sel);
		else {
			// Add selection
			var idMap = new Map();
			for(tid in tool.getSelectedValue())
				idMap.set(tid,true);
			for(tid in sel)
				idMap.set(tid,true);

			var arr = [];
			for(tid in idMap.keys())
				arr.push(tid);
			tool.selectValue(arr);
		}

		renderSelection();
	}


	function onPickerMouseDown(ev:js.jquery.Event) {
		dragStart = {
			bt: ev.button,
			pageX: ev.pageX,
			pageY: ev.pageY,
			// localX: Std.int( ev.offsetX / zoom ),
			// localY: Std.int( ev.offsetY / zoom ),
		}
	}

	function onPickerMouseMove(ev:js.jquery.Event) {
		updateCursor(ev.pageX, ev.pageY);
	}

	function getCursorRect(pageX:Float, pageY:Float) {
		var localX = pageXtoLocal(pageX);
		var localY = pageYtoLocal(pageY);

		var grid = tool.curTilesetDef.tileGridSize;
		var cx = Std.int( localX / grid );
		var cy = Std.int( localY / grid );

		if( dragStart==null )
			return {
				cx: cx,
				cy: cy,
				wid: 1,
				hei: 1,
			}
		else {
			var startCx = Std.int( pageXtoLocal(dragStart.pageX) / grid );
			var startCy = Std.int( pageYtoLocal(dragStart.pageY) / grid );
			return {
				cx: M.imin(cx,startCx),
				cy: M.imin(cy,startCy),
				wid: M.iabs(cx-startCx) + 1,
				hei: M.iabs(cy-startCy) + 1,
			}
		}
	}
}