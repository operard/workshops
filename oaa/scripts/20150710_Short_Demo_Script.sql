--#####################################################
--##
--## Oracle R Enterprise - Short Demo Script
--## July 2015, Mark Hornick
--## (c)2015 Oracle
--##
--#####################################################
-- Random Red Dots

-- Drop the R Embedded Script
begin
  sys.rqScriptDrop('RandomRedDots');
end;
/



-- Generate an image of random red dots and a simple data.frame result
begin
  -- sys.rqScriptDrop('RandomRedDots');
  sys.rqScriptCreate('RandomRedDots',
 'function(){
            id <- 1:10
            plot( 1:100, rnorm(100), pch = 21, 
                  bg = "red", cex = 2 )
            data.frame(id=id, val=id / 100)
            }');
end;
/

-- Return image ony as PNG BLOB, one per image per row
-- Structured content not returned with PNG option
select    ID, IMAGE
from      table(rqEval( NULL,'PNG','RandomRedDots'));

select    ID, IMAGE
from      table(rqEval( cursor(select 250 "ore.png.height" from dual),'PNG','RandomRedDots'));

-- Return structured data only by specifying table definition
select    * 
from      table(rqEval( NULL,'select 1 id, 1 val from dual','RandomRedDots'));

-- Return structured and image content within XML string
select    *
from      table(rqEval(NULL, 'XML', 'RandomRedDots'));


-- Go back to R and invoke

 ore.doEval(FUN.NAME='RandomRedDots');

-- 

select object_name, object_type, last_ddl_time
from user_objects
where object_name like 'ORE$%';

